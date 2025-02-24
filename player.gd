extends Sprite2D

var input = Vector2(1,0)
const max_speed = 200
var movement = Vector2(max_speed,0)

const half_size = 64
const map_size = 5000

@onready
var gameManager = $".."
@onready
var nickname_label = $Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	position = Vector2(ServerClient.initialX, ServerClient.initialY)
	nickname_label.text = ServerClient.nickname
	gameManager.update_self.connect(receive_pos)

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
	
	# Mantém dentro dos limites do mapa
	position.x = clamp(position.x, half_size, map_size - half_size)
	position.y = clamp(position.y, half_size, map_size - half_size)

	# Envia a direção para o servidor
	ServerClient.send_movement(input)

func receive_pos(playerData):
	if playerData.id != ServerClient.player_id:
		return
	
	position = Vector2(playerData.x, playerData.y)
