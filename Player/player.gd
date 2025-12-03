## Player.gd
## Script principal del héroe jugable.
## Maneja el movimiento, sincronización de red y estadísticas del personaje.

extends CharacterBody2D

#region Constants
## Acciones de input para movimiento (definidas en project.godot)
const INPUT_MOVE_LEFT := "move_left"
const INPUT_MOVE_RIGHT := "move_right"
const INPUT_MOVE_UP := "move_up"
const INPUT_MOVE_DOWN := "move_down"
#endregion

#region Node References
## Referencia al sprite del personaje para efectos visuales (flip, animaciones).
@onready var sprite: Sprite2D = $Sprite2D
#endregion

#region Stats Configuration
## Configuración base de estadísticas del héroe.
## Asignar un Resource HeroStats desde el Inspector para personalizar el personaje.
## Si no se asigna, se creará uno con valores por defecto en _ready().
@export var base_stats: HeroStats

## Estadísticas activas del héroe (instancia runtime).
## Esta es una copia independiente de base_stats para trackear HP y modificadores.
var stats: HeroStats

## Dirección actual del movimiento (normalizada).
## Útil para otros sistemas como apuntado o animaciones.
var current_direction := Vector2.ZERO

## Indica si el personaje está mirando hacia la derecha.
## Se usa para el flip del sprite.
var facing_right := true
#endregion

#region Network Interpolation
## Variables para interpolación suave de otros jugadores
var network_position := Vector2.ZERO
var network_velocity := Vector2.ZERO
var interpolation_speed := 10.0
var position_threshold := 100.0  # Distancia máxima para interpolación vs teletransporte
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
	_setup_network_synchronization()


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


## Configura la sincronización de red para interpolación suave.
func _setup_network_synchronization() -> void:
	# Inicializar variables de red con la posición actual
	network_position = global_position
	network_velocity = velocity
	
	# Conectar la señal de cambio de propiedades del MultiplayerSynchronizer
	var synchronizer = get_node("MultiplayerSynchronizer")
	if synchronizer:
		# En Godot 4.x, podemos usar MultiplayerSynchronizer.delta_synchronized
		# para detectar cuando se reciben actualizaciones
		synchronizer.delta_synchronized.connect(_on_network_data_received)
	else:
		push_warning("Player: No se encontró MultiplayerSynchronizer")


## Callback para cuando se reciben datos de red del MultiplayerSynchronizer.
func _on_network_data_received() -> void:
	if not is_multiplayer_authority():
		# Actualizar variables de interpolación cuando lleguen datos nuevos
		network_position = position
		network_velocity = velocity
#endregion

#region Movement
func _physics_process(delta: float) -> void:
	# is_multiplayer_authority() devuelve true si MI ID de red coincide con
	# la autoridad que acabamos de configurar arriba.
	if is_multiplayer_authority():
		_handle_movement()
		_update_sprite_direction()
	else:
		# Para otros jugadores, interpolar suavemente a la posición de red
		_handle_network_interpolation(delta)


## Procesa el input de movimiento y aplica la velocidad usando stats.move_speed.
## Usa Input.get_vector() para normalizar automáticamente el vector de dirección,
## evitando que el movimiento diagonal sea más rápido.
func _handle_movement() -> void:
	# get_vector normaliza automáticamente, evitando velocidad diagonal excesiva
	current_direction = Input.get_vector(
		INPUT_MOVE_LEFT, 
		INPUT_MOVE_RIGHT, 
		INPUT_MOVE_UP, 
		INPUT_MOVE_DOWN
	)
	
	var current_speed := stats.move_speed if stats else 300.0
	velocity = current_direction * current_speed
	
	# move_and_slide usa física correcta para no atravesar paredes
	move_and_slide()


## Actualiza la dirección visual del sprite según el movimiento horizontal.
## Hace flip del sprite cuando el personaje cambia de dirección.
func _update_sprite_direction() -> void:
	if not sprite:
		return
	
	# Solo actualizar si hay movimiento horizontal significativo
	if abs(current_direction.x) > 0.1:
		var should_face_right := current_direction.x > 0
		
		# Solo hacer flip si cambió la dirección
		if should_face_right != facing_right:
			facing_right = should_face_right
			sprite.flip_h = not facing_right
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

#region Network Interpolation
## Maneja la interpolación suave de la posición para jugadores remotos.
## Se ejecuta solo en clientes que NO tienen autoridad sobre este jugador.
func _handle_network_interpolation(delta: float) -> void:
	# Calcular la distancia al objetivo
	var distance_to_target := global_position.distance_to(network_position)
	
	# Si la distancia es muy grande, teletransportar inmediatamente
	if distance_to_target > position_threshold:
		global_position = network_position
		velocity = network_velocity
	else:
		# Interpolación suave hacia la posición objetivo
		global_position = global_position.lerp(network_position, interpolation_speed * delta)
		velocity = velocity.lerp(network_velocity, interpolation_speed * delta)
	
	# Actualizar dirección visual basada en la velocidad de red
	if network_velocity.length() > 0.1:
		current_direction = network_velocity.normalized()
		_update_sprite_direction()


## Callback llamado automáticamente cuando se reciben datos de red.
## Actualiza las variables de interpolación para otros jugadores.
func _on_network_position_changed() -> void:
	if not is_multiplayer_authority():
		network_position = position
		network_velocity = velocity
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


## Retorna la dirección actual de movimiento normalizada.
func get_current_direction() -> Vector2:
	return current_direction


## Retorna true si el personaje está mirando hacia la derecha.
func is_facing_right() -> bool:
	return facing_right
#endregion
