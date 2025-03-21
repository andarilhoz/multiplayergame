extends Node2D

signal update_self
signal murdered
signal grow(size)
signal respawn(x, y)

var otherPlayerPrefab = preload("res://other_player.tscn")
var foodPrefab = preload("res://food.tscn")
var other_players = {}
var foods = {}
const max_size = 2240
const half_size = 64

const leaderBoard = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ServerClient.update_players.connect(_receive_data)
	ServerClient.player_connected.connect(_new_player)
	ServerClient.player_disconnected.connect(_remove_player)
	ServerClient.food_eaten.connect(_food_eaten)
	ServerClient.food_spawn.connect(_food_spawn)
	ServerClient.kill.connect(_kill)
	ServerClient.player_respawn.connect(_respawn)
	
	for player in ServerClient.players:
		if player.id == ServerClient.player_id:
			continue
		_new_player(player.id, player.nickname, player.x, player.y, player.size)
	
	for food in ServerClient.foods:
		generate_food(food.id, food.x, food.y);

func _respawn(playerId, x, y):
	if playerId == ServerClient.player_id:
		print("player respawn")
		respawn.emit(x, y);
	if other_players.has(playerId):
		var current_other = other_players.get(playerId)
		var size = half_size*2
		current_other.position = Vector2(x, y)
		current_other.size = size
		current_other.scale = Vector2(size/ float(half_size), size/ float(half_size));
		current_other.visible = true
	else:
		print("nao encontrado")
	

func _kill(assassin, victim, victim_size):
	print("Player ", assassin, " killed: ", victim, " size: ", victim_size)
	if victim == ServerClient.player_id:
		murdered.emit()
		_player_increase_size(assassin, int(victim_size/2))
		return
	if assassin == ServerClient.player_id:
		grow.emit(int(victim_size/2))
		_disable_player(victim)
		return
	
	_disable_player(victim)
	_player_increase_size(assassin, int(victim_size/2))
	
func _food_spawn(foods):
	for food in foods:
		generate_food(food.id, food.x, food.y)

func _food_eaten(foodId, playerId):
	if foods.has(foodId):
		foods[foodId].queue_free()
		foods.erase(foodId)
	else:
		print("Comida nao encontrada id: ", foodId)
		
	if playerId == ServerClient.player_id:
		return
		
	_player_increase_size(playerId)

func _player_increase_size(playerId, new_size = 1):
	if other_players.has(playerId):
		var eater = other_players.get(playerId)
		if eater.size < max_size:
			eater.size += new_size
			eater.scale = Vector2(eater.size/ float(half_size), eater.size/ float(half_size));
	else:
		print("nao encontrado")

func _receive_data(json):
	for player in json["players"]:
		if player.id == ServerClient.player_id:
			update_self.emit(player)
			continue;
			
		var current_other = other_players.get(player.id)		
		if current_other == null:
			return;
		
		current_other.target_position = Vector2(player.x, player.y)

func _new_player(player_id, nickname, x, y, size = half_size*2):
	print("Novo jogador conectado: ", nickname, player_id)
	var current_other = other_players.get(player_id)
	print("Other: ", current_other)
	if current_other == null:
		other_players[player_id] = otherPlayerPrefab.instantiate()
		#leaderBoard[player_id].score = 0;
		current_other = other_players[player_id]
		add_child(other_players[player_id])
		current_other.label.text = nickname
		current_other.target_position = Vector2(x, y)
		current_other.size = size
		current_other.scale = Vector2(size/ float(half_size), size/ float(half_size));


func generate_food(food_id, x, y):
	foods[food_id] = foodPrefab.instantiate()
	add_child(foods[food_id])
	foods[food_id].label.text = str(food_id);
	foods[food_id].position = Vector2(x, y)

func _disable_player(playerId):
	if other_players.has(playerId):
		other_players[playerId].visible = false
	else:
		print("nao encontrado")

func _remove_player(playerId):
	if other_players.has(playerId):
		print("deletado")
		other_players[playerId].queue_free()
		other_players.erase(playerId)
	else:
		print("nao encontrado")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
