extends Sprite2D

var target_position: Vector2
@onready
var label = $Label
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	target_position = position
	pass # Replace with function body.

func _physics_process(delta: float) -> void:
	position = position.lerp(target_position, delta * 10)
