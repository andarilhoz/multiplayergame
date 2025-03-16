extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ServerClient.ping_updated.connect(_update_ping);
	pass # Replace with function body.


func _update_ping(value):
	text = "Ping: "+ str(value) + "ms"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
