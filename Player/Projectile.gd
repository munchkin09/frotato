extends Area2D

@export_range(50.0, 1000.0, 10.0) var speed: float = 400.0
@export_range(0.1, 10.0, 0.1) var max_distance: float = 800.0
@export var damage: float = 10.0

var _direction: Vector2 = Vector2.RIGHT
var _start_position: Vector2

func _ready() -> void:
	_start_position = global_position
	add_to_group("player_projectiles")
	if has_node("CollisionShape2D"):
		var shape: CollisionShape2D = $CollisionShape2D
		shape.disabled = false
	if has_node("Timer"):
		$Timer.start()

func set_direction(dir: Vector2) -> void:
	if dir.length() > 0.0:
		_direction = dir.normalized()
		rotation = _direction.angle()

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	if global_position.distance_to(_start_position) > max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		if body.has_method("apply_damage"):
			body.apply_damage(damage)
		queue_free()

func _on_timer_timeout() -> void:
	queue_free()
