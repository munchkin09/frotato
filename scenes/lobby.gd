extends Control

# Referencias a los Nodos de UI usando Unique Names (%)
@onready var panel_connect = %PanelConnect
@onready var panel_waiting = %PanelWaitingRoom
@onready var name_input = %NameInput
@onready var ip_input = %IpInput
@onready var player_list_container = %PlayerListContainer
@onready var error_label = %ErrorLabel
@onready var start_button = %StartGameButton
@onready var role_button = %RoleButton

func _ready():
	# Conectamos las señales del NetworkManager
	NetworkManager.player_list_changed.connect(refresh_lobby_ui)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	
	# Aseguramos el estado inicial de la UI
	panel_connect.visible = true
	panel_waiting.visible = false
	error_label.text = ""

# --- EVENTOS DE BOTONES DE CONEXIÓN ---

func _on_host_button_pressed():
	if name_input.text == "":
		error_label.text = "¡Necesitas un nombre!"
		return
		
	NetworkManager.player_info.name = name_input.text
	NetworkManager.create_game() # Crea servidor
	
	# El host entra directo al lobby
	_show_waiting_room()

func _on_join_button_pressed():
	if name_input.text == "":
		error_label.text = "¡Necesitas un nombre!"
		return

	NetworkManager.player_info.name = name_input.text
	var ip = ip_input.text
	if ip == "":
		ip = "127.0.0.1"
		
	NetworkManager.join_game(ip) # Intenta conectar
	error_label.text = "Conectando..."
	# Nota: No mostramos la sala de espera hasta que NetworkManager 
	# confirme la conexión mediante la señal 'player_list_changed' o success.

# --- EVENTOS DENTRO DEL LOBBY ---

# FRO-21: Función _on_role_button_pressed eliminada.
# El rol de Overlord es exclusivo del Host y no se puede cambiar.
# El botón de rol se oculta en refresh_lobby_ui().

func _on_start_game_button_pressed():
	# Solo el Host (authority) puede dar la orden
	if multiplayer.is_server():
		# Llamamos a la RPC start_game en el NetworkManager
		NetworkManager.rpc("start_game")

# --- ACTUALIZACIÓN DE UI ---

func _show_waiting_room():
	panel_connect.visible = false
	panel_waiting.visible = true
	refresh_lobby_ui()

func refresh_lobby_ui():
	# Si estábamos conectando y recibimos datos, mostramos la sala
	if panel_connect.visible:
		_show_waiting_room()
	
	# Limpiar lista anterior
	for child in player_list_container.get_children():
		child.queue_free()
	
	# Verificar si soy Host para mostrar el botón de Iniciar
	start_button.visible = multiplayer.is_server()
	
	# Validaciones básicas para el botón START (1 Overlord, +1 Frotato)
	var overlords = 0
	var frotatos = 0
	
	# Rellenar lista
	for id in NetworkManager.players:
		var p = NetworkManager.players[id]
		var label = Label.new()
		
		# Formato: "Nombre [Rol] (HOST/OVERLORD)"
		var text = p.name + " [" + p.role + "]"
		if id == 1:
			text += " (HOST/OVERLORD)"
		
		# Color diferente para el usuario local
		if id == multiplayer.get_unique_id():
			text = ">> " + text + " <<"
			label.modulate = Color.GREEN
			
		label.text = text
		player_list_container.add_child(label)
		
		# Conteo para validación
		if p.role == "Overlord": overlords += 1
		else: frotatos += 1
	
	# Lógica simple de validación visual
	# FRO-21: Siempre habrá 1 Overlord (el Host), solo validamos que haya Frotatos
	if multiplayer.is_server():
		if overlords == 1 and frotatos >= 1:
			start_button.disabled = false
			start_button.text = "INICIAR PARTIDA"
		else:
			start_button.disabled = true
			start_button.text = "Esperando jugadores (Frotatos)"

# --- GESTIÓN DE ERRORES ---

func _on_connection_failed():
	panel_connect.visible = true
	panel_waiting.visible = false
	error_label.text = "Error: No se pudo conectar al servidor."

func _on_server_disconnected():
	# FRO-20: Si el Host se desconecta, mostrar aviso y volver al Menú Principal
	print("Host desconectado. Regresando al menú principal...")
	
	# Limpiamos datos locales
	NetworkManager.players.clear()
	
	# Mostrar aviso antes de cambiar de escena
	# Usamos un Timer para dar tiempo al usuario de ver el mensaje
	panel_connect.visible = true
	panel_waiting.visible = false
	error_label.text = "El servidor ha cerrado la sala. Regresando al menú..."
	
	# Crear timer para volver al menú principal después de mostrar el aviso
	var timer = get_tree().create_timer(2.0) # 2 segundos de espera
	await timer.timeout
	
	# Cambiar a la escena del menú principal
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
