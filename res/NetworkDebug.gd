## NetworkDebug.gd
## Script de debug para diagnosticar problemas de red en el juego.
## Añade este script como autoload temporal para monitorear la sincronización.

extends Node

## Activa/desactiva el debug visual
var debug_enabled := true  # Temporalmente activado para debugging

## Referencia a los jugadores para debug
var players: Array[Node] = []

func _ready() -> void:

	if debug_enabled:
		print("[NetworkDebug] Sistema de debug activado")
		print("  F1 - Mostrar info de red")
		print("  F2 - Resetear posiciones")
		print("  F3 - Detectar parpadeos")
		print("  F4 - Toggle debug on/off")
	else:
		print("[NetworkDebug] Sistema de debug DESACTIVADO - usa F4 para activar")

func _input(event: InputEvent) -> void:
	# Usamos _input para capturar eventos globales ANTES de que la UI los consuma.
	# Ideal para herramientas de debug que deben funcionar siempre.
	if event is InputEventKey and event.pressed:
		var keycode = event.keycode

		# La tecla F4 siempre debe funcionar para activar/desactivar el debug
		if keycode == KEY_F4:
			debug_enabled = not debug_enabled
			print("[NetworkDebug] Debug %s." % ("ACTIVADO" if debug_enabled else "DESACTIVADO"))
			get_viewport().set_input_as_handled() # Consumimos el evento para que no se propague más
			return

		# Si el debug no está activado, ignoramos el resto de teclas de función
		if not debug_enabled:
			return

		# Procesar otras teclas de debug solo si está habilitado
		if keycode == KEY_F1:
			_print_network_debug()
			get_viewport().set_input_as_handled()
		elif keycode == KEY_F2:
			_reset_network_positions()
			get_viewport().set_input_as_handled()
		elif keycode == KEY_F3:
			_detect_flickering_issues()
			get_viewport().set_input_as_handled()
		else:
			pass

## Registra un jugador para debug
func register_player(player: Node) -> void:
	if player not in players:
		players.append(player)
		print("[NetworkDebug] Jugador %s registrado" % player.name)

## Desregistra un jugador del debug
func unregister_player(player: Node) -> void:
	players.erase(player)
	print("[NetworkDebug] Jugador %s desregistrado" % player.name)

## Imprime información de debug de todos los jugadores
func _print_network_debug() -> void:
	print("\n=== NETWORK DEBUG INFO ===")
	for player in players:
		if player and player.has_method("debug_network_state"):
			var debug_info = player.debug_network_state()
			print("[Player %s] Auth: %s | Pos: %s | Net: %s | Dist: %.1f" % [
				player.name,
				debug_info.is_authority,
				debug_info.position,
				debug_info.network_position,
				debug_info.distance_to_network
			])
	print("========================\n")

## Resetea las posiciones de red para corregir desincronización
func _reset_network_positions() -> void:
	print("[NetworkDebug] Reseteando posiciones de red...")
	for player in players:
		if player and player.has_method("_setup_network_synchronization"):
			player._setup_network_synchronization()

## Detecta posibles problemas de parpadeo
func _detect_flickering_issues() -> void:
	for player in players:
		if player and player.has_method("debug_network_state"):
			var debug_info = player.debug_network_state()
			
			# Detectar saltos grandes de posición
			if debug_info.distance_to_network > 50.0:
				print("[NetworkDebug] POSIBLE PARPADEO en %s - Distancia: %.1f" % [
					player.name, debug_info.distance_to_network
				])
			
			# Detectar problemas de autoridad
			if debug_info.is_authority and debug_info.distance_to_network > 10.0:
				print("[NetworkDebug] CONFLICTO DE AUTORIDAD en %s" % player.name)

## Función para llamar desde consola de Godot
func force_debug() -> void:
	_print_network_debug()
	_detect_flickering_issues()
