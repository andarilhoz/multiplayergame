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

signal update_players
signal player_disconnected(player_id)

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
	print("Mandando novo movimento")
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
	# 🔹 Verifica mensagens TCP do servidor
	if tcp_client.get_status() == StreamPeerTCP.STATUS_CONNECTED and tcp_client.get_available_bytes() > 0:
		var response = tcp_client.get_utf8_string(tcp_client.get_available_bytes())
		process_server_message(response)

	# 🔹 Verifica mensagens UDP do servidor
	if udp_client.get_available_packet_count() > 0:
		var response = udp_client.get_packet().get_string_from_utf8()
		print("📩 Resposta UDP recebida:", response)
		var json = JSON.parse_string(response)
		if json and "players" in json:
			update_players.emit(json)

# **Novo: Processa mensagens TCP do servidor**
func process_server_message(received_data):
	var json_data = JSON.parse_string(received_data)
	if json_data == null:
		print("❌ Erro ao processar JSON do servidor.")
		return

	if json_data.has("type"):
		match json_data["type"]:
			"player_disconnect":
				handle_player_disconnect(json_data)
			"game_update":
				update_players.emit(json_data)
			"connect":
				player_id = json_data["playerId"]
				nickname = json_data["nickname"]
				initialX = json_data["x"]
				initialY = json_data["y"]
				print("🎮 ID do jogador:", player_id)
				udp_client.set_dest_address(server_ip, udp_port)
				switch_to_game_scene()
			_:
				print("📩 Mensagem TCP não reconhecida:", json_data)

# **Novo: Remove jogadores quando eles desconectam**
func handle_player_disconnect(json_data):
	var disconnected_id = json_data["playerId"]
	print("🔴 Jogador desconectado:", disconnected_id)
	player_disconnected.emit(disconnected_id)

# Alterna para a cena do jogo
func switch_to_game_scene():
	get_tree().change_scene_to_file("res://game.tscn")
