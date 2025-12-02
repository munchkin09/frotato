extends CharacterBody2D

func _enter_tree():
	# _enter_tree se ejecuta justo cuando el Spawner crea el nodo.
	# Configuramos la autoridad basándonos en el nombre del nodo.
	# Como en Arena.gd pusimos "new_player.name = str(id)", aquí recuperamos esa ID.
	set_multiplayer_authority(name.to_int())

func _physics_process(delta):
	# is_multiplayer_authority() devuelve true si MI ID de red coincide con
	# la autoridad que acabamos de configurar arriba.
	if is_multiplayer_authority():
		var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = direction * 300
		move_and_slide()
