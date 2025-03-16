extends Control

var server_ip = "127.0.0.1"
var udp_port = 7777
var tcp_port = 5555

var tcp_client = StreamPeerTCP.new()
var udp_client = PacketPeerUDP.new()

var player_id = -1
var nickname = ""

var lastMessage = ""
var initialX = 0
var initialY = 0
var foods = [];
var players = [];

var ping_start_time = 0.0
var last_ping = 0.0
var ping_interval = 1.0
var max_ping_timeout = 2000  # 2 segundos de timeout
var last_received_ping_time = 0.0

signal update_players
signal player_connected(player_id, nickname, x, y, size)
signal player_disconnected(player_id)
signal food_eaten(food_id, player_id)
signal food_spawn(foods)
signal ping_updated(ping_value)
signal kill(assassin, victim, victim_size)
signal player_respawn(playerId, x, y)

# Chamado quando o nó entra na árvore da cena
func _ready() -> void:
	print("🚀 Cliente Iniciado...")
	connect_to_server()

# Conecta ao servidor via TCP
func connect_to_server():
	print("🔄 Tentando conectar ao servidor...")
	
	var err = tcp_client.connect_to_host(server_ip, tcp_port)
	if err != OK:
		print("❌ Erro ao conectar ao servidor TCP:", err)
		return

	# Espera um pouco para garantir que a conexão seja estabelecida
	await get_tree().create_timer(0.2).timeout
	
	# Confirma se a conexão foi bem-sucedida
	tcp_client.poll()
	if tcp_client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		print("✅ Conectado ao servidor TCP!")
	else:
		print("❌ Falha na conexão TCP!")

# Envia o nickname do jogador para o servidor
func send_nickname(nickname_input_text):
	var request = JSON.stringify({"nickname": nickname_input_text})
	print("📩 Enviando nickname:", request)

	tcp_client.put_data(request.to_utf8_buffer())
	tcp_client.poll()

# Envia a movimentação do jogador via UDP
func send_movement(movement: Vector2):
	var message = JSON.stringify({
		"type": "move",
		"playerId": player_id,
		"x": movement.x,
		"y": movement.y
	})
	if lastMessage == message:
		return

	lastMessage = message
	udp_client.put_packet(message.to_utf8_buffer())

# Envia mensagens personalizadas via UDP
func send_udp_message(data):
	if player_id == -1:
		print("❌ Tentativa de enviar mensagem UDP sem ID do jogador!")
		return  

	var message = JSON.stringify(data)
	var err = udp_client.put_packet(message.to_utf8_buffer())

	if err == OK:
		print("✅ Mensagem UDP enviada:", message)
	else:
		print("❌ Falha ao enviar UDP! Código de erro:", err)

# **Novo: Ouvindo mensagens TCP constantemente no `_process()`**
func _process(delta):
	if udp_client.get_available_packet_count() > 0:
		var current_time = Time.get_ticks_msec()
		var response = udp_client.get_packet().get_string_from_utf8()
		process_udp_messages(response)
		
	last_ping += delta
	last_received_ping_time += delta * 1000  # Converter para milissegundos
	
	# 🔹 Verifica mensagens TCP do servidor
	if tcp_client.get_status() == StreamPeerTCP.STATUS_CONNECTED and tcp_client.get_available_bytes() > 0:
		var response = tcp_client.get_utf8_string(tcp_client.get_available_bytes())
		var messages = response.split("\n", false)
		for message in messages:
			message = message.strip_edges()
			if message.is_empty():
				continue
			process_tcp_message(message)

	# 🔹 Verifica mensagens UDP do servidor

		
	if last_ping >= ping_interval:
		send_ping()
		last_ping = 0.0
		
	if last_received_ping_time >= max_ping_timeout:
		print("⚠️ Ping Timeout - Pacote perdido!")
		last_received_ping_time = 0
			
func process_udp_messages(message):
	var json_data = JSON.parse_string(message)
	if json_data and "type" in json_data:
		match json_data["type"]:
			"pong":
				var received_timestamp = int(json_data["timestamp"])
				var current_time = Time.get_ticks_msec()
				var ping_value = current_time - received_timestamp
				emit_signal("ping_updated", ping_value)
				print("ServerTimeEpoch: ", received_timestamp, "Local: ", current_time)
				last_received_ping_time = 0  # Reseta o timeout, pois recebeu um pong
				print("📡 Ping: ", ping_value, "ms")
				ping_updated.emit(ping_value);
			"update":
				update_players.emit(json_data)
			_:
				print("📩 Mensagem UDP não reconhecida:", json_data)
			
			
# **Novo: Processa mensagens TCP do servidor**
func process_tcp_message(received_data):
	var json_data = JSON.parse_string(received_data)
	if json_data == null:
		print("❌ Erro ao processar JSON do servidor. ", received_data)
		return
	
	if json_data.has("type"):
		match json_data["type"]:
			"player_disconnect":
				handle_player_disconnect(json_data)
			"player_connect":
				handle_player_connect(json_data)
			"game_update":
				update_players.emit(json_data)
			"connect":
				handle_connect(json_data)
				switch_to_game_scene()
			"food_spawn":
				handle_food_spawn(json_data)
			"food_eaten":
				handle_food_eaten(json_data)
			"kill":
				var assassin = json_data["assassin"]
				var victim = json_data["victim"]
				var victim_size = json_data["victimSize"]
				kill.emit(assassin, victim, victim_size)
			"respawn":
				handle_player_respawn(json_data)
			_:
				print("📩 Mensagem TCP não reconhecida:", json_data)

func handle_player_respawn(json_data):
	var other_id = json_data["id"]	
	var x = json_data["x"]
	var y = json_data["y"]	
	print("Jogador respawnou:", other_id)
	player_respawn.emit(other_id, x, y)

func handle_food_spawn(json_data):
	food_spawn.emit(json_data["foods"])

func handle_food_eaten(json_data):
	var foodId = json_data["id"]
	var playerId = json_data["playerId"]
	food_eaten.emit(foodId, playerId)

func handle_connect(json_data):
	player_id = json_data["id"]
	print("Json data ", json_data)
	foods = json_data["foods"]
	print("🎮 ID do jogador:", player_id)
	
	for player in json_data["players"]:
		if player.id == player_id:
			nickname = player.nickname
			initialX = player.x
			initialY = player.y
			print("Set player data ", nickname)
			continue
			
		players.append(
			{
				"id": player.id, 
				"nickname": player.nickname, 
				"x": player.x, 
				"y": player.y,
				"size": player.size
			}
		)
		
	
	udp_client.set_dest_address(server_ip, udp_port)
	await get_tree().create_timer(0.2).timeout
	send_ping()

# **Novo: Remove jogadores quando eles desconectam**
func handle_player_disconnect(json_data):
	var disconnected_id = json_data["id"]
	print("🔴 Jogador desconectado:", disconnected_id)
	player_disconnected.emit(disconnected_id)

func handle_player_connect(json_data):
	var other_id = json_data["id"]
	if(other_id == player_id):
		return;
	var nickname = json_data["nickname"]
	var x = json_data["x"]
	var y = json_data["y"]
	print("Jogador conectado:", other_id)
	player_connected.emit(other_id, nickname, x, y, 64)


func send_ping():
	ping_start_time = Time.get_ticks_msec()
	var ping_data = {
		"type": "ping",
		"timestamp": ping_start_time
	}
	udp_client.put_packet(JSON.stringify(ping_data).to_utf8_buffer())

# Alterna para a cena do jogo
func switch_to_game_scene():
	get_tree().change_scene_to_file("res://game.tscn")
