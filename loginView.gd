extends Panel

var game_scene = preload("res://game.tscn").instantiate()

@onready
var nickname_input : LineEdit = $NicknameInput

@onready
var server_client = $"../ServerClient"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_send_btn_pressed() -> void:
	var nickname = nickname_input.text
	var response = await ServerClient.send_nickname(nickname)
	print(response)
	
