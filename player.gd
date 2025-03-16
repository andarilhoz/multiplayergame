extends Sprite2D

var input = Vector2(1,0)
const max_speed = 200
const min_speed = 10
var movement = Vector2(max_speed,0)

const min_size = 64
const map_size = 2000
const max_size = 500

@onready
var gameManager = $".."
@onready
var nickname_label = $Label
@onready
var camera = $"../Camera2D";

var size = 64;
var score = 0;

var server_position;

var max_server_distance = 50;

var alive = true;


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ServerClient.food_eaten.connect(_food_eaten)
	position = Vector2(ServerClient.initialX, ServerClient.initialY)
	nickname_label.text = ServerClient.nickname
	gameManager.update_self.connect(receive_pos)
	gameManager.murdered.connect(_die)
	gameManager.grow.connect(_grow)
	gameManager.respawn.connect(_respawn)
	
func _die():
	alive = false
	size = min_size;
	scale = Vector2(size/ float(min_size), size/ float(min_size));
	print("I died");

func _respawn(x, y):
	alive = true;
	position = Vector2(x, y);

func _grow(grow_size):
	print("Player pos before grow: ", position)
	print("Player growing ", grow_size)
	print("Size before: ", size)
	if size < max_size:
		size += grow_size
		scale = Vector2(size/ float(min_size), size/ float(min_size));
	score += grow_size;
	print("Player pos after grow: ", position)
	print("Final size", size);

func _food_eaten(foodId, playerId):
	if playerId != ServerClient.player_id:
		return
	
	if size < max_size:
		size += 1
		scale = Vector2(size/ float(min_size), size/ float(min_size));
	
	print("Scale: ", scale)
	score += 1

# Chamado a cada frame
func _process(delta: float) -> void:
	update_direction()

# Chamado a cada frame de física
func _physics_process(delta):
	player_movement(delta)
			
	camera.position = lerp (camera.position, position, .1)
	update_camera_zoom(delta)
	ServerClient.send_movement(input)

func update_direction():
	var mouse_position = get_global_mouse_position()
	var direction_to_mouse = (mouse_position - position).normalized()
	
	# Só atualiza a direção se o mouse estiver distante o suficiente
	if direction_to_mouse.length() > 0.1:
		input = direction_to_mouse

func get_speed():
	var fator: float = float(size - min_size) / float(max_size - min_size)
	fator = clamp(fator, 0.0, 1.0)

	var expoente = 3.0 # mais alto = mais lento no final
	return max_speed - pow(fator, expoente) * (max_speed - min_speed)

func update_camera_zoom(delta):
	var fator: float = float(size - min_size) / float(max_size - min_size)
	fator = clamp(fator, 0.0, 1.0)

	var zoom_min = 0.2
	var zoom_max = 1.0
	var target_zoom = zoom_max - fator * (zoom_max - zoom_min)

	var current_zoom = camera.zoom.x # x e y são iguais

	# Se o zoom já está perto do alvo, não faz nada
	if abs(current_zoom - target_zoom) < 0.01:
		return

	var smooth_zoom = lerp(current_zoom, target_zoom, 5 * delta)
	camera.zoom = Vector2(smooth_zoom, smooth_zoom)

func player_movement(delta):
	if !alive:
		return
		
	# Aplica a direção como movimento contínuo
	movement = input * get_speed()
	position += movement * delta
	
	var oldX = position.x
	var oldY = position.y
	
	position.x = clampf(position.x, size, map_size - size)
	position.y = clampf(position.y, size, map_size - size)
		
	if server_position:
		if position.distance_to(server_position) > max_server_distance: 
			print("Server Pos:", server_position, "current: ", position)
			position = server_position
			server_position = null

func receive_pos(playerData):	
	server_position = Vector2(playerData.x, playerData.y);
