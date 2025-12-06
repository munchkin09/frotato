extends Node2D

const PLAYER_SCENE = preload("res://Player/Player.tscn")
const ENEMY_SCENE = preload("res://Enemies/Basic/BaseEnemy.tscn"
)
@onready var spawner = $MultiplayerSpawner
@onready var enemy = $MultiplayerSpawner_Enemies
func _ready():
	
	# SOLO EL HOST genera los jugadores
	if multiplayer.is_server():
		spawn_players()

func spawn_players():
	for id in NetworkManager.players:
		var p_info = NetworkManager.players[id]
		var new_player = PLAYER_SCENE.instantiate()
		
		# Asignar el ID es CRÍTICO para la autoridad
		new_player.name = str(id)
		
		# Posicionamiento básico aleatorio para que no salgan pegados
		new_player.position = Vector2(400, 300) + Vector2(randf_range(-100, 100), randf_range(-100, 100))
		
		# Al añadirlo como hijo, el MultiplayerSpawner detectará el nodo
		# y lo replicará automáticamente en todos los clientes.
		add_child(new_player)

func spawn_enemy():
	var new_enemy = ENEMY_SCENE.instantiate()
	
	# Posicionamiento básico aleatorio para que no salgan pegados
	new_enemy.position = Vector2(400, 300) + Vector2(randf_range(-100, 100), randf_range(-100, 100))
	
	# Al añadirlo como hijo, el MultiplayerSpawner detectará el nodo
	# y lo replicará automáticamente en todos los clientes.
	add_child(new_enemy)

func _on_timer_timeout():
	# SOLO EL HOST genera los jugadores
	if multiplayer.is_server():
		spawn_enemy()
	pass # Replace with function body.
