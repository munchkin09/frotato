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

## Referencia a la HurtBox para detectar colisiones con enemigos.
## La HurtBox es un Area2D que detecta cuando un enemigo entra en contacto con el héroe.
@onready var hurt_box: Area2D = $HurtBox

## Timer para controlar la duración de los I-Frames (invulnerabilidad).
@onready var invulnerability_timer: Timer = $InvulnerabilityTimer

@onready var health_component = $HealthComponent 
@onready var targeting_component: Node = $TargetingComponent
@onready var weapon: Node2D = $Weapon
#endregion

#region Invulnerability System (I-Frames)
## Duración de la invulnerabilidad en segundos cuando el héroe recibe daño.
## Valores recomendados: 0.5s - 1.0s para balance típico de juegos de acción.
@export_range(0.1, 3.0, 0.1) var invulnerability_duration: float = 0.8

## Cantidad de parpadeos durante la invulnerabilidad.
## Mayor número = parpadeo más rápido y visible.
@export_range(1, 20, 1) var blink_count: int = 8

## Indica si el héroe está actualmente invulnerable.
var is_invulnerable: bool = false

## Referencia al Tween activo para el efecto de parpadeo.
var blink_tween: Tween = null
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

var current_target: Node2D = null
#endregion

#region Network Interpolation
## Variables para interpolación suave de otros jugadores
var network_position := Vector2.ZERO
var network_velocity := Vector2.ZERO
var interpolation_speed := 15.0  # Aumentado para mayor responsividad
var position_threshold := 10.0  # Aumentado para evitar teletransportes innecesarios
var min_update_distance := 1.3   # Distancia mínima para actualizar posición
var min_update_velocity := 5.0   # Velocidad mínima para actualizar velocidad
#endregion

#region Death and Spectator System
## Estado actual del jugador
enum PlayerState {
	ALIVE,		## Jugador vivo y activo
	DYING,		## Reproduciendo animación de muerte
	SPECTATOR	## Modo espectador (muerto)
}

## Estado actual del jugador
var current_state: PlayerState = PlayerState.ALIVE

## Referencia al CollisionShape2D para deshabilitar colisiones
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

## Transparencia objetivo para la animación de muerte
var death_alpha_target := 0.3
var death_animation_speed := 3.0

## Señales para el sistema de muerte
signal player_died(player_id: int)
signal player_became_spectator(player_id: int)

## Señal emitida cuando el héroe entra o sale de invulnerabilidad.
signal invulnerability_changed(is_invulnerable: bool)
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
	_setup_invulnerability_system()
	_setup_network_synchronization()
	_connect_to_game_manager()
	_register_with_debug()
	_setup_targeting_and_weapon()

func _setup_targeting_and_weapon() -> void:
	if targeting_component and targeting_component.has_signal("target_changed"):
		targeting_component.target_changed.connect(_on_target_changed)
	if targeting_component.has_method("get_current_target"):
		current_target = targeting_component.get_current_target()
	if weapon and weapon.has_method("set_target"):
		weapon.set_target(current_target)

func _on_target_changed(new_target: Node2D) -> void:
	current_target = new_target
	if weapon and weapon.has_method("set_target"):
		weapon.set_target(current_target)

## Inicializa las estadísticas del héroe.
## Si no hay base_stats asignado, crea uno con valores por defecto.
func _initialize_stats() -> void:
	if base_stats:
		# Crear una instancia independiente para no modificar el Resource compartido
		stats = base_stats.create_instance()
	else:
		# Crear estadísticas por defecto si no se asignó ninguna
		stats = HeroStats.new()
		stats.create_instance()
		push_warning("Player: No se asignó base_stats, usando valores por defecto.")
	health_component.stats = stats

## Conecta las señales de estadísticas para reaccionar a cambios de HP.
func _connect_stat_signals() -> void:
	if health_component:
		health_component.hp_changed.connect(_on_hp_changed)
		health_component.hero_died.connect(_on_hero_died)
		health_component.damage_taken.connect(_on_damage_taken)
		health_component.healed.connect(_on_healed)
		
		# Conectar señales internas para propagación global
		player_died.connect(_on_player_died_internal)
		player_became_spectator.connect(_on_player_became_spectator_internal)


## Configura el sistema de invulnerabilidad (I-Frames).
## Conecta las señales de la HurtBox y configura el Timer.
func _setup_invulnerability_system() -> void:
	# Configurar el Timer de invulnerabilidad
	if invulnerability_timer:
		invulnerability_timer.wait_time = invulnerability_duration
		invulnerability_timer.one_shot = true
		invulnerability_timer.timeout.connect(_on_invulnerability_timer_timeout)
	else:
		push_warning("Player: InvulnerabilityTimer no encontrado. El sistema de I-Frames no funcionará.")
	
	# Conectar la señal de la HurtBox para detectar colisiones con enemigos
	if hurt_box:
		hurt_box.area_entered.connect(_on_hurt_box_area_entered)
		hurt_box.body_entered.connect(_on_hurt_box_body_entered)
		print("[Player %s] Sistema de HurtBox configurado correctamente." % name)
	else:
		push_warning("Player: HurtBox no encontrada. El héroe no detectará colisiones con enemigos.")


## Configura la sincronización de red para interpolación suave.
func _setup_network_synchronization() -> void:
	# Solo el jugador con autoridad debe inicializar y enviar su posición.
	# Los clientes remotos recibirán estos valores a través del MultiplayerSynchronizer.
	if is_multiplayer_authority():
		# Esperar un frame para que la posición inicial esté establecida por el spawner
		await get_tree().process_frame
		# Inicializar variables de red con la posición actual para el primer envío
		network_position = global_position
		network_velocity = Vector2.ZERO

	# Nota: El MultiplayerSynchronizer se encarga de actualizar las propiedades
	# 'network_position' y 'network_velocity' en los clientes remotos.
	# No se necesitan callbacks adicionales como 'delta_synchronized' si la
	# interpolación se maneja directamente en _physics_process.
#endregion

#region Death System

## Inicia la secuencia de muerte del jugador.
func _start_death_sequence() -> void:
	if current_state != PlayerState.ALIVE:
		return  # Ya está muriendo o muerto
	
	print("[Player %s] Iniciando secuencia de muerte..." % name)
	current_state = PlayerState.DYING
	
	# Deshabilitar física y colisiones inmediatamente
	_disable_physics()
	
	# Reproducir feedback visual/sonoro
	_play_death_feedback()


## Deshabilita la física y colisiones del jugador.
func _disable_physics() -> void:
	# Deshabilitar colisiones
	if collision_shape:
		collision_shape.disabled = true
	
	# Detener movimiento
	velocity = Vector2.ZERO
	
	# Opcional: Deshabilitar procesamiento de input
	set_physics_process(true)  # Mantener activo para animación de muerte


## Reproduce efectos visuales y sonoros de muerte.
func _play_death_feedback() -> void:
	# TODO: Reproducir sonido de muerte
	# AudioManager.play_sound("player_death")
	
	# Efecto visual: hacer el sprite semi-transparente
	if sprite:
		# Crear un tween para animar la transparencia
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", death_alpha_target, 1.0)
		tween.tween_callback(_finish_death_sequence)


## Maneja la animación durante el estado de muerte.
func _handle_death_animation(delta: float) -> void:
	# Animación simple: rotación lenta
	if sprite:
		sprite.rotation += death_animation_speed * delta


## Finaliza la secuencia de muerte y entra en modo espectador.
func _finish_death_sequence() -> void:
	print("[Player %s] Entrando en modo espectador" % name)
	current_state = PlayerState.SPECTATOR
	
	# Emitir señal de espectador
	player_became_spectator.emit(name.to_int())
	
	# Deshabilitar completamente el procesamiento físico
	set_physics_process(false)
	
	# El personaje "desaparece" visualmente pero el nodo permanece
	# para mantener la cámara activa si es necesario
	if sprite:
		sprite.visible = false


## Conecta este jugador con el GameManager global.
func _connect_to_game_manager() -> void:
	# Solo conectar si el GameManager está disponible
	if GameManager:
		GameManager.connect_player_signals(self)
		print("[Player %s] Conectado al GameManager" % name)
	else:
		push_warning("Player: GameManager no está disponible")


## Se ejecuta cuando el nodo está siendo liberado
func _exit_tree() -> void:
	# Desconectar del GameManager al salir
	if GameManager:
		GameManager.disconnect_player_signals(self)
	
	# Desregistrarse del NetworkDebug
	if NetworkDebug:
		NetworkDebug.unregister_player(self)


## Registra este jugador con el sistema de debug de red
func _register_with_debug() -> void:
	if NetworkDebug:
		NetworkDebug.register_player(self)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("ui_accept") and can_act():
		if weapon and weapon.has_method("try_attack"):
			weapon.try_attack()


## Callbacks internos para propagación de señales globales.
func _on_player_died_internal(player_id: int) -> void:
	# Las señales ya se propagan automáticamente a través del GameManager
	print("[Player %s] Señal de muerte propagada al GameManager" % name)


func _on_player_became_spectator_internal(player_id: int) -> void:
	# Las señales ya se propagan automáticamente a través del GameManager
	print("[Player %s] Señal de espectador propagada al GameManager" % name)


## Verifica si el jugador puede realizar acciones (está vivo).
func can_act() -> bool:
	return current_state == PlayerState.ALIVE


## Retorna el estado actual del jugador.
func get_player_state() -> PlayerState:
	return current_state


## Revive al jugador (para futuras mecánicas de resurrección).
func revive() -> void:
	if current_state == PlayerState.SPECTATOR:
		print("[Player %s] ¡Reviviendo!" % name)
		
		# Restaurar estado
		current_state = PlayerState.ALIVE
		
		# Restaurar física
		if collision_shape:
			collision_shape.disabled = false
		
		# Restaurar visual
		if sprite:
			sprite.visible = true
			sprite.modulate.a = 1.0
			sprite.rotation = 0.0
		
		# Restaurar HP
		if stats:
			stats.restore_full_hp()
		
		# Reactivar procesamiento
		set_physics_process(true)
		
		# Resetear invulnerabilidad
		is_invulnerable = false
#endregion

#region Damage & Invulnerability System (I-Frames)
## Callback cuando un Area2D (enemigo con Area2D) entra en la HurtBox.
## Esto detecta colisiones con proyectiles enemigos o zonas de daño.
## @param area: El Area2D que entró en contacto
func _on_hurt_box_area_entered(area: Area2D) -> void:
	# Solo procesar si somos la autoridad y estamos vivos
	if not is_multiplayer_authority() or current_state != PlayerState.ALIVE:
		return
	
	# Ignorar si estamos invulnerables
	if is_invulnerable:
		print("[Player %s] Colisión ignorada (invulnerable)" % name)
		return
	
	# Verificar si el área es un enemigo o proyectil enemigo
	# Los enemigos deben estar en el grupo "enemies" o tener un método "get_damage()"
	if area.is_in_group("enemies") or area.is_in_group("enemy_projectiles"):
		var damage := _get_damage_from_source(area)
		_apply_damage_with_invulnerability(damage)
		print("[Player %s] ¡Golpeado por Area2D enemigo! Daño: %.1f" % [name, damage])


## Callback cuando un CharacterBody2D/RigidBody2D (enemigo con cuerpo físico) entra en la HurtBox.
## Esto detecta colisiones directas con enemigos que usan CharacterBody2D.
## @param body: El cuerpo físico que entró en contacto
func _on_hurt_box_body_entered(body: Node2D) -> void:
	# Solo procesar si somos la autoridad y estamos vivos
	if not is_multiplayer_authority() or current_state != PlayerState.ALIVE:
		return
	
	# Ignorar si estamos invulnerables
	if is_invulnerable:
		print("[Player %s] Colisión con cuerpo ignorada (invulnerable)" % name)
		return
	
	# Verificar si el cuerpo es un enemigo
	if body.is_in_group("enemies"):
		var damage := _get_damage_from_source(body)
		_apply_damage_with_invulnerability(damage)
		print("[Player %s] ¡Golpeado por enemigo! Daño: %.1f" % [name, damage])


## Obtiene el daño de una fuente de daño.
## Si la fuente tiene un método get_damage(), lo usa. Si no, usa daño por defecto.
## @param source: El nodo que causa el daño
## @return: La cantidad de daño a aplicar
func _get_damage_from_source(source: Node) -> float:
	# Intentar obtener el daño del enemigo si tiene el método
	if source.has_method("get_damage"):
		return source.get_damage()
	
	# Si tiene una propiedad "damage", usarla
	if "damage" in source:
		return source.damage
	
	# Daño por defecto si no se puede determinar
	return 10.0


## Aplica daño al héroe y activa la invulnerabilidad.
## @param damage: Cantidad de daño a aplicar
func _apply_damage_with_invulnerability(damage: float) -> void:
	# Aplicar el daño
	take_damage(damage)
	
	# Activar invulnerabilidad solo si seguimos vivos
	if stats and stats.is_alive():
		_start_invulnerability()


## Inicia el periodo de invulnerabilidad.
func _start_invulnerability() -> void:
	if is_invulnerable:
		return  # Ya estamos invulnerables
	
	print("[Player %s] ¡Invulnerabilidad activada por %.1fs!" % [name, invulnerability_duration])
	is_invulnerable = true
	invulnerability_changed.emit(true)
	
	# Iniciar el timer
	if invulnerability_timer:
		invulnerability_timer.wait_time = invulnerability_duration
		invulnerability_timer.start()
	
	# Iniciar el efecto de parpadeo
	_start_blink_effect()


## Finaliza el periodo de invulnerabilidad.
func _end_invulnerability() -> void:
	print("[Player %s] Invulnerabilidad terminada." % name)
	is_invulnerable = false
	invulnerability_changed.emit(false)
	
	# Detener y limpiar el efecto de parpadeo
	_stop_blink_effect()


## Callback cuando el Timer de invulnerabilidad termina.
func _on_invulnerability_timer_timeout() -> void:
	_end_invulnerability()


## Inicia el efecto visual de parpadeo durante la invulnerabilidad.
## Usa un Tween para animar el alpha del sprite entre visible e invisible.
func _start_blink_effect() -> void:
	if not sprite:
		return
	
	# Cancelar cualquier tween anterior
	_stop_blink_effect()
	
	# Crear nuevo tween para el parpadeo
	blink_tween = create_tween()
	blink_tween.set_loops(blink_count)  # Repetir N veces
	
	# Calcular duración de cada ciclo de parpadeo
	var blink_duration := invulnerability_duration / (blink_count * 2.0)
	
	# Secuencia de parpadeo: invisible -> visible
	blink_tween.tween_property(sprite, "modulate:a", 0.3, blink_duration)
	blink_tween.tween_property(sprite, "modulate:a", 1.0, blink_duration)
	
	# Asegurar que el sprite quede visible al terminar
	blink_tween.tween_callback(_ensure_sprite_visible)


## Detiene el efecto de parpadeo y restaura la visibilidad normal del sprite.
func _stop_blink_effect() -> void:
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
		blink_tween = null
	
	_ensure_sprite_visible()


## Asegura que el sprite sea completamente visible.
func _ensure_sprite_visible() -> void:
	if sprite and current_state == PlayerState.ALIVE:
		sprite.modulate.a = 1.0
#endregion

#region Movement
func _physics_process(delta: float) -> void:
	# Manejar animaciones de muerte independientemente de la autoridad
	if current_state == PlayerState.DYING:
		_handle_death_animation(delta)
		return
	
	# is_multiplayer_authority() devuelve true si MI ID de red coincide con
	# la autoridad que acabamos de configurar arriba.
	if is_multiplayer_authority():
		# Solo procesar movimiento si el jugador está vivo
		if current_state == PlayerState.ALIVE:
			_handle_movement()
			_update_sprite_direction()
			# Actualizar variables de red para otros clientes
			network_position = global_position
			network_velocity = velocity
	else:
		# Para otros jugadores, interpolar suavemente a la posición de red
		if current_state == PlayerState.ALIVE:
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
		
		# Solo hacer flip si cambió la dirección (evitar parpadeos)
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
	print("[Player %s] ¡Ha muerto!" % name)
	
	# Solo el cliente con autoridad inicia el proceso de muerte
	if is_multiplayer_authority():
		_start_death_sequence()
	
	# Emitir señal para notificar al GameMode
	player_died.emit(name.to_int())


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
	# Verificar que tenemos datos válidos de red
	if network_position == Vector2.ZERO:
		return
	
	# Calcular la distancia al objetivo
	var distance_to_target := global_position.distance_to(network_position)
	
	# Si la distancia es muy grande, teletransportar inmediatamente
	if distance_to_target > position_threshold:
		global_position = network_position
		velocity = network_velocity
		print("[Player %s] Teletransporte: distancia %.1f > %.1f" % [name, distance_to_target, position_threshold])
	else:
		# Interpolación suave hacia la posición objetivo
		# Usar un factor de interpolación adaptivo basado en la distancia
		var lerp_factor = minf(interpolation_speed * delta, 1.0)
		global_position = global_position.lerp(network_position, lerp_factor)
		velocity = velocity.lerp(network_velocity, lerp_factor)
	
	# Actualizar dirección visual basada en la velocidad de red
	if network_velocity.length() > 0.1:
		current_direction = network_velocity.normalized()
		_update_sprite_direction()
	else:
		# Si no hay velocidad, mantener la dirección actual
		current_direction = Vector2.ZERO


#endregion

#region Public API
## Aplica daño al héroe desde fuentes externas.
## Respeta el estado de invulnerabilidad: si el héroe está en I-Frames, el daño es ignorado.
## @param amount: Cantidad de daño a aplicar
## @param ignore_invulnerability: Si es true, ignora la invulnerabilidad (para daño ambiental, etc.)
func take_damage(amount: float, ignore_invulnerability: bool = false) -> void:
	# Verificar invulnerabilidad
	if is_invulnerable and not ignore_invulnerability:
		print("[Player %s] Daño bloqueado por invulnerabilidad" % name)
		return
	
	if health_component:
		health_component.apply_damage(amount)

## Cura al héroe desde fuentes externas.
## @param amount: Cantidad de curación a aplicar
func heal(amount: float) -> void:
	if health_component:
		health_component.heal(amount)
		#stats.heal(amount)


## Retorna el rango de recolección de items del héroe.
func get_pickup_range() -> float:
	return stats.pickup_range if stats else 50.0


## Retorna el daño base del héroe para cálculos de armas.
func get_base_damage() -> float:
	return stats.base_damage if stats else 10.0


## Verifica si el héroe está vivo.
func is_alive() -> bool:
	return health_component.is_alive() if health_component else true


## Verifica si el héroe está actualmente invulnerable (en I-Frames).
func is_currently_invulnerable() -> bool:
	return is_invulnerable


## Retorna la dirección actual de movimiento normalizada.
func get_current_direction() -> Vector2:
	return current_direction


## Retorna true si el personaje está mirando hacia la derecha.
func is_facing_right() -> bool:
	return facing_right


## Función de debug para verificar el estado de sincronización.
func debug_network_state() -> Dictionary:
	return {
		"is_authority": is_multiplayer_authority(),
		"position": global_position,
		"network_position": network_position,
		"velocity": velocity,
		"network_velocity": network_velocity,
		"distance_to_network": global_position.distance_to(network_position),
		"current_state": current_state,
		"facing_right": facing_right,
		"is_invulnerable": is_invulnerable
	}
#endregion
