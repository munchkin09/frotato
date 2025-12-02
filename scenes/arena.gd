extends Node2D

const PLAYER_SCENE = preload("res://Player/Player.tscn")

@onready var spawner = $MultiplayerSpawner

func _ready():
	
	# SOLO EL HOST genera los jugadores
	if multiplayer.is_server():
		spawn_players()

func spawn_players():
	for id in NetworkManager.players:
		var p_info = NetworkManager.players[id]
		var new_player = PLAYER_SCENE.instantiate()
		
		# Asignar el ID es CRÍTICO para la autoridad
		new_player.player_id = id 
		
		# Posicionamiento básico aleatorio para que no salgan pegados
		new_player.position = Vector2(400, 300) + Vector2(randf_range(-100, 100), randf_range(-100, 100))
		
		# Al añadirlo como hijo, el MultiplayerSpawner detectará el nodo
		# y lo replicará automáticamente en todos los clientes.
		add_child(new_player)
