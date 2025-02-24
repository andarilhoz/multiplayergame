extends Node2D

signal update_self

var otherPlayerPrefab = preload("res://other_player.tscn")
var other_players = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ServerClient.update_players.connect(_receive_data)
	ServerClient.player_disconnected.connect(_remove_player)


func _receive_data(json):
	for player in json["players"]:
		if player.id == ServerClient.player_id:
			update_self.emit(player)
			continue;
		
		var current_other = other_players.get(player.id)
		
		if current_other == null:
			other_players[player.id] = otherPlayerPrefab.instantiate()
			current_other = other_players[player.id]
			add_child(other_players[player.id])
		
		current_other.label.text = player.nickname
		current_other.target_position = Vector2(player.x, player.y)
		

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
