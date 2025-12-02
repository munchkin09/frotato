extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	# Simula ser Host si ejecutas normal, o Cliente si ejecutas otra instancia
	if DisplayServer.get_name() == "headless":
		pass 

	# Para pruebas rápidas manuales desde el editor:
	# Descomenta una de estas lineas en dos instancias distintas de Godot

	# Instancia 1:
	# NetworkManager.create_game()

	# Instancia 2 (Ejecutar tras la 1):
	# NetworkManager.player_info.name = "Cliente"
	# NetworkManager.join_game()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
