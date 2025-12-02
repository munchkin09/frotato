## Player.gd
## Script principal del héroe jugable.
## Maneja el movimiento, sincronización de red y estadísticas del personaje.

extends CharacterBody2D

#region Stats Configuration
## Configuración base de estadísticas del héroe.
## Asignar un Resource HeroStats desde el Inspector para personalizar el personaje.
## Si no se asigna, se creará uno con valores por defecto en _ready().
@export var base_stats: HeroStats

## Estadísticas activas del héroe (instancia runtime).
## Esta es una copia independiente de base_stats para trackear HP y modificadores.
var stats: HeroStats
#endregion

#region Lifecycle
func _enter_tree() -> void:
	# _enter_tree se ejecuta justo cuando el Spawner crea el nodo.
	# Configuramos la autoridad basándonos en el nombre del nodo.
	# Como en Arena.gd pusimos "new_player.name = str(id)", aquí recuperamos esa ID.
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	_initialize_stats()
	_connect_stat_signals()


## Inicializa las estadísticas del héroe.
## Si no hay base_stats asignado, crea uno con valores por defecto.
func _initialize_stats() -> void:
	if base_stats:
		# Crear una instancia independiente para no modificar el Resource compartido
		stats = base_stats.create_instance()
	else:
		# Crear estadísticas por defecto si no se asignó ninguna
		stats = HeroStats.new()
		stats.initialize()
		push_warning("Player: No se asignó base_stats, usando valores por defecto.")


## Conecta las señales de estadísticas para reaccionar a cambios de HP.
func _connect_stat_signals() -> void:
	if stats:
		stats.hp_changed.connect(_on_hp_changed)
		stats.hero_died.connect(_on_hero_died)
		stats.damage_taken.connect(_on_damage_taken)
		stats.healed.connect(_on_healed)
#endregion

#region Movement
func _physics_process(_delta: float) -> void:
	# is_multiplayer_authority() devuelve true si MI ID de red coincide con
	# la autoridad que acabamos de configurar arriba.
	if is_multiplayer_authority():
		_handle_movement()


## Procesa el input de movimiento y aplica la velocidad usando stats.move_speed.
func _handle_movement() -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var current_speed := stats.move_speed if stats else 300.0
	velocity = direction * current_speed
	move_and_slide()
#endregion

#region Stats Callbacks
## Callback cuando el HP del héroe cambia.
## @param new_hp: Nuevo valor de HP
## @param max_hp: Valor máximo de HP
func _on_hp_changed(new_hp: float, max_hp: float) -> void:
	# TODO: Actualizar UI de barra de vida
	# TODO: Sincronizar HP con otros clientes si es necesario
	print("[Player %s] HP: %.1f / %.1f (%.0f%%)" % [name, new_hp, max_hp, stats.get_hp_percentage() * 100])


## Callback cuando el héroe muere.
func _on_hero_died() -> void:
	# TODO: Implementar lógica de muerte (animación, respawn, game over, etc.)
	print("[Player %s] ¡Ha muerto!" % name)


## Callback cuando el héroe recibe daño.
## @param damage_amount: Cantidad de daño recibido
func _on_damage_taken(damage_amount: float) -> void:
	# TODO: Reproducir efecto de daño, sonido, etc.
	print("[Player %s] Recibió %.1f de daño" % [name, damage_amount])


## Callback cuando el héroe es curado.
## @param heal_amount: Cantidad de curación recibida
func _on_healed(heal_amount: float) -> void:
	# TODO: Reproducir efecto de curación, sonido, etc.
	print("[Player %s] Curado por %.1f" % [name, heal_amount])
#endregion

#region Public API
## Aplica daño al héroe desde fuentes externas.
## @param amount: Cantidad de daño a aplicar
func take_damage(amount: float) -> void:
	if stats:
		stats.take_damage(amount)


## Cura al héroe desde fuentes externas.
## @param amount: Cantidad de curación a aplicar
func heal(amount: float) -> void:
	if stats:
		stats.heal(amount)


## Retorna el rango de recolección de items del héroe.
func get_pickup_range() -> float:
	return stats.pickup_range if stats else 50.0


## Retorna el daño base del héroe para cálculos de armas.
func get_base_damage() -> float:
	return stats.base_damage if stats else 10.0


## Verifica si el héroe está vivo.
func is_alive() -> bool:
	return stats.is_alive() if stats else true
#endregion
