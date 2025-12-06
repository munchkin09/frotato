extends Node

## TargetingComponent.gd
# Componente para detectar y mantener referencia al enemigo más cercano en el rango de visión.
# Emite la señal `target_changed(new_target)` cuando el objetivo cambia.

signal target_changed(new_target)

@export var vision_area_path: NodePath
var _enemies_in_range: Array = []
var _current_target: Node = null

func _ready():
	var area = get_node(vision_area_path)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		_enemies_in_range.append(body)

func _on_body_exited(body):
	if body.is_in_group("enemies"):
		_enemies_in_range.erase(body)
		if body == _current_target:
			_update_target()

func _physics_process(_delta):
	_update_target()

func _update_target():
	var player = get_parent()
	var min_dist = INF
	var closest = null
	for enemy in _enemies_in_range:
		if not is_instance_valid(enemy):
			continue
		var dist = player.global_position.distance_squared_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = enemy
	if closest != _current_target:
		_current_target = closest
		emit_signal("target_changed", _current_target)
	# Limpia referencia si el objetivo muere o sale del rango
	if _current_target and not is_instance_valid(_current_target):
		_current_target = null
		emit_signal("target_changed", null)

func get_current_target():
	return _current_target
