extends Node2D

@export var projectile_scene: PackedScene
@export_range(0.05, 5.0, 0.05) var attack_cooldown: float = 0.8

var _current_target: Node2D = null
var _can_attack: bool = true

@onready var _cooldown_timer: Timer = $CooldownTimer

func _ready() -> void:
	if _cooldown_timer:
		_cooldown_timer.wait_time = attack_cooldown
		_cooldown_timer.one_shot = true
		_cooldown_timer.timeout.connect(_on_cooldown_timeout)

func set_target(target: Node2D) -> void:
	_current_target = target

func try_attack() -> void:
	if not _can_attack:
		return
	if not _current_target or not is_instance_valid(_current_target):
		return
	if not projectile_scene:
		push_warning("Weapon: projectile_scene no asignado")
		return

	look_at(_current_target.global_position)
	var projectile := projectile_scene.instantiate()
	if projectile is Node2D:
		projectile.global_position = global_position
		if projectile.has_method("set_direction"):
			var dir := ( _current_target.global_position - global_position ).normalized()
			projectile.set_direction(dir)
		get_tree().current_scene.add_child(projectile)
	else:
		push_warning("Weapon: el proyectil no es Node2D")

	_can_attack = false
	if _cooldown_timer:
		_cooldown_timer.start()

func _on_cooldown_timeout() -> void:
	_can_attack = true
