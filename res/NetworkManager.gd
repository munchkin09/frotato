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
var player_info = {
	"name": "Player", 
	"role": "Hero", # Roles: "Hero", "Overlord"
	"id": 0 # Se asignará al conectar
}

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
	player_info.id = 1 
	players[1] = player_info
	player_list_changed.emit()
	print("Servidor creado. Esperando jugadores...")

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
	print("Jugador desconectado: ", id)
	if players.has(id):
		players.erase(id)
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
	
	# 1. Guardar al nuevo jugador en el diccionario del servidor
	players[new_player_id] = new_player_info
	print("Servidor: Registrado nuevo jugador ", new_player_info.name)
	
	# 2. Enviar el diccionario ACTUALIZADO a TODOS los clientes (incluido el nuevo)
	# Esto asegura que todos tengan la lista completa
	rpc("update_player_list", players)

# Esta función la llama el servidor y se ejecuta en TODOS los clientes
@rpc("authority", "call_local", "reliable")
func update_player_list(server_player_list):
	players = server_player_list
	player_list_changed.emit()
	print("Lista de jugadores actualizada: ", players.size(), " jugadores.")

# Función extra para cambiar de rol (FRO-F1-003 adelantado)
@rpc("any_peer", "call_local", "reliable")
func change_role(new_role):
	var sender_id = multiplayer.get_remote_sender_id()
	if players.has(sender_id):
		players[sender_id].role = new_role
		# Si soy el servidor, replico el cambio a todos
		if multiplayer.is_server():
			rpc("update_player_list", players)
