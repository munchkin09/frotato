extends CharacterBody2D

@export var player_id := 1:
	set(id):
		player_id = id
		# Esto es importante: El nombre del nodo DEBE ser el ID para que el Spawner funcione bien
		name = str(player_id)
		$MultiplayerSynchronizer.set_multiplayer_authority(id)

func _ready():
	# Si yo soy la autoridad de este muñeco (es MÍO), lo controlo
	if $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
		modulate = Color.GREEN # Píntalo verde para saber que es el tuyo
	else:
		modulate = Color.WHITE

func _physics_process(delta):
	# Solo procesar input si soy el dueño de este personaje
	if $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
		var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = direction * 300
		move_and_slide()
