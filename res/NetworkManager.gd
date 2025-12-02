extends Node

# Señales para que la UI se entere de lo que pasa
signal player_list_changed # Se emite cuando cambia la lista de jugadores
signal connection_failed # Se emite si falla al unirse
signal server_disconnected # Se emite si el host cierra la sala

# Constantes de conexión
const PORT = 7000
const MAX_CLIENTS = 4
const DEFAULT_SERVER_IP = "127.0.0.1"

# Información del jugador local
# NOTA: El rol por defecto es "Frotato" para clientes.
# Solo el Host tendrá el rol "Overlord" (asignado en create_game).
var player_info = {
	"name": "Player", 
	"role": "Frotato", # Roles: "Frotato", "Overlord" (exclusivo del Host)
	"id": 0 # Se asignará al conectar
}

# Referencia al prefab del jugador
var player_scene = preload("res://Player/Player.tscn") 
# Diccionario de TODOS los jugadores conectados: { id: { name, role, id } }
var players = {}

func _ready():
	# Conectamos las señales nativas del sistema multiplayer de Godot
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# --- FUNCIONES DE CONEXIÓN (FRO-F1-001) ---

func create_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		print("Error al crear servidor: ", error)
		return
	
	multiplayer.multiplayer_peer = peer
	
	# El Host también es un jugador, así que lo registramos localmente
	# FRO-21: El Host SIEMPRE es el Overlord
	player_info.id = 1 
	player_info.role = "Overlord"
	players[1] = player_info
	player_list_changed.emit()
	print("Servidor creado como Overlord. Esperando jugadores...")

func join_game(ip_address = ""):
	if ip_address == "":
		ip_address = DEFAULT_SERVER_IP
		
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, PORT)
	if error != OK:
		print("Error al crear cliente: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
	print("Intentando unirse a: ", ip_address)

func leave_game():
	multiplayer.multiplayer_peer = null
	players.clear()
	player_list_changed.emit()

# --- CALLBACKS DEL MOTOR (Lo que Godot nos dice) ---

func _on_peer_connected(id):
	# Se ejecuta en TODOS cuando alguien nuevo entra.
	# Pero la lógica de registro la manejamos vía RPC abajo.
	print("Jugador conectado: ", id)

func _on_peer_disconnected(id):
	# FRO-20: Gestión de desconexiones (Cleanup)
	# Esta función se ejecuta en TODOS cuando alguien se desconecta.
	print("Jugador desconectado: ", id)
	
	# Solo el servidor gestiona la eliminación y sincronización
	if multiplayer.is_server():
		if players.has(id):
			var disconnected_player_name = players[id].name
			players.erase(id)
			print("Servidor: Eliminado jugador '", disconnected_player_name, "' del diccionario.")
			
			# Reenviar el diccionario actualizado a todos los clientes restantes
			rpc("update_player_list", players)
			
			# Emitir señal local también para actualizar UI del servidor
			player_list_changed.emit()

func _on_connected_to_server():
	print("¡Conexión exitosa al servidor!")
	var my_id = multiplayer.get_unique_id()
	player_info.id = my_id
	
	# Paso clave: Enviar mis datos al servidor para que me registre
	# Usamos RPC para llamar a la función en el ID 1 (Servidor)
	rpc_id(1, "register_player", player_info)

func _on_connection_failed():
	print("Fallo al conectar")
	connection_failed.emit()

func _on_server_disconnected():
	print("El servidor se ha desconectado")
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()

# --- RPCs y SINCRONIZACIÓN (FRO-F1-002) ---

# Esta función se ejecuta solo en el servidor (id 1) cuando un cliente la llama
@rpc("any_peer", "call_remote", "reliable")
func register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	
	# FRO-21: Forzamos el rol "Frotato" a todos los clientes que se conectan
	# Solo el Host (id=1) puede ser Overlord
	new_player_info.role = "Frotato"
	
	# 1. Guardar al nuevo jugador en el diccionario del servidor
	players[new_player_id] = new_player_info
	print("Servidor: Registrado nuevo jugador ", new_player_info.name, " como Frotato")
	
	# 2. Enviar el diccionario ACTUALIZADO a TODOS los clientes (incluido el nuevo)
	# Esto asegura que todos tengan la lista completa
	rpc("update_player_list", players)

# Esta función la llama el servidor y se ejecuta en TODOS los clientes
@rpc("authority", "call_local", "reliable")
func update_player_list(server_player_list):
	players = server_player_list
	player_list_changed.emit()
	print("Lista de jugadores actualizada: ", players.size(), " jugadores.")

# FRO-21: Función change_role eliminada.
# El rol de Overlord es exclusivo del Host y no se puede cambiar.
# Los clientes siempre son "Frotato".

# --- GESTIÓN DE LA PARTIDA (FRO-F1-005) ---

@rpc("authority", "call_local", "reliable")
func start_game():
	# Esta función la llama el servidor, pero se ejecuta en TODOS (call_local)
	
	# Cambiamos la escena
	var scene_path = "res://scenes/Arena.tscn"
	get_tree().change_scene_to_file(scene_path)
	
	print("Cargando Arena de combate...")
