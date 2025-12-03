## GameManager.gd
## Singleton global para manejar el estado del juego y eventos importantes.
## Coordina la lógica de muerte, fin de partida y comunicación entre sistemas.

extends Node

#region Signals
## Emitida cuando un jugador muere
signal player_died(player_id: int)

## Emitida cuando un jugador entra en modo espectador
signal player_became_spectator(player_id: int)

## Emitida cuando se verifica si la partida ha terminado
signal game_over_check_requested()

## Emitida cuando la partida termina (todos los héroes muertos)
signal game_over(reason: String)

## Emitida cuando los héroes ganan (boss derrotado)
signal heroes_victory()
#endregion

#region Game State
## Lista de IDs de jugadores activos
var active_players: Array[int] = []

## Lista de IDs de jugadores muertos
var dead_players: Array[int] = []

## Número total de héroes en la partida
var total_heroes: int = 3

## Indica si la partida está activa
var game_active: bool = false
#endregion

#region Lifecycle
func _ready() -> void:
	print("[GameManager] Sistema de gestión de juego inicializado")
	# Conectar señales internas
	player_died.connect(_on_player_died)
	player_became_spectator.connect(_on_player_became_spectator)


## Inicializa el GameManager para una nueva partida.
## @param hero_count: Número de héroes en la partida
func initialize_game(hero_count: int = 3) -> void:
	total_heroes = hero_count
	active_players.clear()
	dead_players.clear()
	game_active = true
	
	print("[GameManager] Juego inicializado con %d héroes" % total_heroes)


## Registra un jugador como activo en la partida.
## @param player_id: ID del jugador a registrar
func register_player(player_id: int) -> void:
	if player_id not in active_players:
		active_players.append(player_id)
		print("[GameManager] Jugador %d registrado" % player_id)


## Desregistra un jugador de la partida.
## @param player_id: ID del jugador a desregistrar
func unregister_player(player_id: int) -> void:
	active_players.erase(player_id)
	dead_players.erase(player_id)
	print("[GameManager] Jugador %d desregistrado" % player_id)
#endregion

#region Death Management
## Callback cuando un jugador muere.
## @param player_id: ID del jugador que murió
func _on_player_died(player_id: int) -> void:
	if not game_active:
		return
		
	print("[GameManager] Procesando muerte del jugador %d" % player_id)
	
	# Agregar a lista de muertos si no está ya
	if player_id not in dead_players:
		dead_players.append(player_id)
	
	# Remover de activos
	active_players.erase(player_id)
	
	# Verificar condición de game over
	_check_game_over_condition()


## Callback cuando un jugador entra en modo espectador.
## @param player_id: ID del jugador que se convirtió en espectador
func _on_player_became_spectator(player_id: int) -> void:
	print("[GameManager] Jugador %d ahora es espectador" % player_id)
	# Aquí se puede añadir lógica específica para espectadores


## Verifica si se cumple la condición de game over.
func _check_game_over_condition() -> void:
	var living_heroes = get_living_heroes_count()
	
	print("[GameManager] Verificando condición de fin: %d héroes vivos" % living_heroes)
	
	if living_heroes <= 0:
		_trigger_game_over("Todos los héroes han muerto")
	
	# Emitir señal para otros sistemas que quieran reaccionar
	game_over_check_requested.emit()


## Dispara el fin de partida.
## @param reason: Razón del fin de partida
func _trigger_game_over(reason: String) -> void:
	if not game_active:
		return
		
	game_active = false
	print("[GameManager] ¡Fin del juego! Razón: %s" % reason)
	game_over.emit(reason)


## Dispara la victoria de los héroes.
func trigger_heroes_victory() -> void:
	if not game_active:
		return
		
	game_active = false
	print("[GameManager] ¡Los héroes han ganado!")
	heroes_victory.emit()
#endregion

#region Public API
## Retorna el número de héroes vivos.
func get_living_heroes_count() -> int:
	return active_players.size()


## Retorna el número de héroes muertos.
func get_dead_heroes_count() -> int:
	return dead_players.size()


## Verifica si un jugador específico está vivo.
## @param player_id: ID del jugador a verificar
func is_player_alive(player_id: int) -> bool:
	return player_id in active_players


## Verifica si un jugador específico está muerto.
## @param player_id: ID del jugador a verificar
func is_player_dead(player_id: int) -> bool:
	return player_id in dead_players


## Retorna el estado actual del juego.
func is_game_active() -> bool:
	return game_active


## Obtiene estadísticas del juego actual.
func get_game_stats() -> Dictionary:
	return {
		"total_heroes": total_heroes,
		"living_heroes": get_living_heroes_count(),
		"dead_heroes": get_dead_heroes_count(),
		"active_players": active_players.duplicate(),
		"dead_players": dead_players.duplicate(),
		"game_active": game_active
	}


## Revive a un jugador (para mecánicas futuras).
## @param player_id: ID del jugador a revivir
func revive_player(player_id: int) -> void:
	if player_id in dead_players:
		dead_players.erase(player_id)
		active_players.append(player_id)
		print("[GameManager] Jugador %d ha sido revivido" % player_id)


## Resetea el GameManager para una nueva partida.
func reset_game() -> void:
	active_players.clear()
	dead_players.clear()
	game_active = false
	print("[GameManager] Estado del juego reseteado")
#endregion

#region Network Integration
## Conecta las señales de muerte de un jugador al GameManager.
## Debe ser llamado cuando se instancia un nuevo jugador.
## @param player: Referencia al nodo del jugador
func connect_player_signals(player: Node) -> void:
	if player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
	
	if player.has_signal("player_became_spectator"):
		player.player_became_spectator.connect(_on_player_became_spectator)
	
	# Registrar automáticamente el jugador
	var player_id = player.name.to_int()
	register_player(player_id)
	
	print("[GameManager] Señales del jugador %d conectadas" % player_id)


## Desconecta las señales de un jugador del GameManager.
## @param player: Referencia al nodo del jugador
func disconnect_player_signals(player: Node) -> void:
	if player.has_signal("player_died"):
		if player.player_died.is_connected(_on_player_died):
			player.player_died.disconnect(_on_player_died)
	
	if player.has_signal("player_became_spectator"):
		if player.player_became_spectator.is_connected(_on_player_became_spectator):
			player.player_became_spectator.disconnect(_on_player_became_spectator)
	
	# Desregistrar el jugador
	var player_id = player.name.to_int()
	unregister_player(player_id)
	
	print("[GameManager] Señales del jugador %d desconectadas" % player_id)
#endregion
