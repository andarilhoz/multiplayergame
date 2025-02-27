extends Sprite2D

var input = Vector2(1,0)
const max_speed = 200
var movement = Vector2(max_speed,0)

const half_size = 64
const map_size = 5000
const max_size = 2240

@onready
var gameManager = $".."
@onready
var nickname_label = $Label

var size = 64;
var score = 0;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ServerClient.food_eaten.connect(_food_eaten)
	position = Vector2(ServerClient.initialX, ServerClient.initialY)
	nickname_label.text = ServerClient.nickname
	gameManager.update_self.connect(receive_pos)


func _food_eaten(foodId, playerId):
	if playerId != ServerClient.player_id:
		return
	
	if size < max_size:
		size += 1
		scale = Vector2(size/ float(half_size), size/ float(half_size));
	
	print("Scale: ", scale)
	score += 1

# Chamado a cada frame
func _process(delta: float) -> void:
	update_direction()

# Chamado a cada frame de física
func _physics_process(delta):
	player_movement(delta)

func update_direction():
	var mouse_position = get_global_mouse_position()
	var direction_to_mouse = (mouse_position - position).normalized()
	
	# Só atualiza a direção se o mouse estiver distante o suficiente
	if direction_to_mouse.length() > 0.1:
		input = direction_to_mouse

func player_movement(delta):
	# Aplica a direção como movimento contínuo
	movement = input * max_speed
	position += movement * delta
	
	position.x = clamp(position.x, size, map_size - size)
	position.y = clamp(position.y, size, map_size - size)

	# Envia a direção para o servidor
	ServerClient.send_movement(input)

func receive_pos(playerData):
	if playerData.id != ServerClient.player_id:
		return
	
	position = lerp (position, Vector2(playerData.x, playerData.y), 1)
