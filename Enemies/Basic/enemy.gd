extends CharacterBody2D
class_name BaseEnemy

# --- CONFIGURACIÓN ---
@export_category("Stats")
@export var speed: float = 120.0
@export var damage_amount: int = 10
@export var detection_range: float = 500.0

@export_category("Components")
@export var nav_agent: NavigationAgent2D
# Asumimos que tendrás un nodo HealthComponent, aquí referenciamos su ruta o señal
@onready var health_component = $HealthComponent 

# --- VARIABLES ---
var target_body: Node2D = null

func _ready() -> void:
	# En Godot 4, es vital configurar esto para evitar errores de sincronización
	# Si usamos un MultiplayerSpawner, la autoridad se asigna automáticamente, 
	# pero es buena práctica asegurarlo.
	nav_agent.path_desired_distance = 10.0
	nav_agent.target_desired_distance = 10.0
	velocity = Vector2(0,0)
	
	# OPTIMIZACIÓN: No calcular path en cada frame. 
	# Usamos un Timer o un contador simple. Aquí configuramos el intervalo del NavAgent.
	# Hacemos que la búsqueda de ruta ocurra cada 0.2 segundos aprox.
	nav_agent.path_max_distance = 100.0

func _physics_process(_delta: float) -> void:
	# 1. NETWORK GUARD: Si no soy el servidor, no calculo movimiento.
	# El MultiplayerSynchronizer moverá al 'dummy' en los clientes.
	if not is_multiplayer_authority():
		return

	# 2. BUSCAR OBJETIVO (Si no tengo o si quiero actualizar el más cercano)
	_update_target_logic()
	
	if target_body == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 3. NAVEGACIÓN
	# Le decimos al agente dónde está el jugador ahora
	nav_agent.target_position = target_body.global_position
	
	if nav_agent.is_navigation_finished():
		# Lógica si llega al destino exacto (opcional)
		pass

	# Obtenemos la siguiente posición en la ruta
	var current_agent_position = global_position
	var next_path_position = nav_agent.get_next_path_position()

	# Calculamos la nueva velocidad
	var new_velocity = current_agent_position.direction_to(next_path_position) * speed
	
	# --- AVOIDANCE (OPCIONAL PERO RECOMENDADO PARA HORDAS) ---
	# Si habilitas 'Avoidance' en el nodo NavigationAgent2D, descomenta esto:
	# nav_agent.set_velocity(new_velocity) 
	# Y mueve el 'move_and_slide' a la señal _on_velocity_computed
	
	# Versión simple sin Avoidance complejo:
	velocity = new_velocity
	move_and_slide()
	
	# 4. INTERACCIÓN (DAÑO POR CONTACTO)
	_handle_collision_damage()

# --- LÓGICA DE TARGETING ---
func _update_target_logic() -> void:
	# Optimizacion: Solo buscar jugadores si no tenemos uno o cada X tiempo.
	# Aquí usaremos la estrategia de "El más cercano siempre"
	var players = get_tree().get_nodes_in_group("Players") # ¡Asegúrate de meter a tus jugadores en este grupo!
	var min_dist = INF
	var closest_player = null
	
	for player in players:
		# distance_squared_to es más rápido que distance_to (evita raíz cuadrada)
		var dist = global_position.distance_squared_to(player.global_position)
		if dist < min_dist:
			min_dist = dist
			closest_player = player
			
	target_body = closest_player

# --- LÓGICA DE DAÑO ---
func _handle_collision_damage() -> void:
	# get_slide_collision_count detecta con qué chocó el CharacterBody2D en el último frame
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Verificamos si chocamos con un jugador
		if collider.is_in_group("Players") and collider.has_method("take_damage"):
			# Llamamos al daño. Como estamos en el servidor (Authority), 
			# podemos llamar directamente o usar RPC si el sistema de daño lo requiere.
			collider.take_damage(damage_amount)
			# Opcional: Empuje hacia atrás (Knockback) o cooldown de ataque
			_apply_knockback(collision.get_normal())

func _apply_knockback(normal: Vector2) -> void:
	# Rebote simple
	velocity = normal * 200.0
	move_and_slide()

# --- RECEPCIÓN DE DAÑO (Para conectar con tu HealthComponent) ---
# Esta función la llamará tu Proyectil
func take_damage(amount: int) -> void:
	if health_component:
		health_component.apply_damage(amount)
	else:
		# Fallback si no tienes el componente aún
		queue_free()
