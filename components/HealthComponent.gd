extends Node
class_name HealthComponent

# --- SEÑALES ---
# Emitimos esto para que la Barra de Vida (UI) sepa que debe actualizarse
signal health_changed(current_hp: int, max_hp: int)

# Referencia a tus stats (puede ser un Resource o un Nodo)
# Asumimos que HeroStats es un Resource o clase global
@export var stats: HeroStats
@export var base_max_health: int = 100 # Valor por defecto si no hay Stats (para enemigos simples)

# Emitimos esto para que la entidad sepa que debe morir (animación, queue_free, etc)
#region Signals
## Emitida cuando el HP actual cambia. Útil para actualizar la UI automáticamente.
## @param new_hp: El nuevo valor de HP actual
## @param max_hp: El valor máximo de HP para calcular porcentajes
signal hp_changed(new_hp: float, max_hp: float)

## Emitida cuando el héroe muere (HP llega a 0).
signal hero_died

## Emitida cuando el héroe recibe daño.
## @param damage_amount: Cantidad de daño recibido
signal damage_taken(damage_amount: float)

## Emitida cuando el héroe es curado.
## @param heal_amount: Cantidad de curación efectiva aplicada
signal healed(heal_amount: float)
#endregion


# Estado actual (volátil)
@export var current_health: int :
	set(value):
		# Usamos stats.max_hp para el tope
		var max_hp = stats.max_hp if stats else 100 
		var clamped_value = clampi(value, 0, max_hp)
		
		if current_health != clamped_value:
			current_health = clamped_value
			# Pasamos el max_hp en la señal para la UI
			health_changed.emit(current_health, max_hp)
			if current_health == 0:
				hero_died.emit()

func _ready() -> void:
	# Al iniciar, llenamos la vida basándonos en los stats
	if stats:
		current_health = stats.max_hp
	
	# Opcional: Si tus stats cambian en tiempo real (ej. subes de nivel y aumenta MaxHP),
	# deberías conectar una señal de stats aquí.
	if stats.has_signal("stats_changed"):
		stats.stats_changed.connect(_on_stats_changed)

func apply_damage(amount: int) -> void:
	if not is_multiplayer_authority(): return

	# --- INTEGRACIÓN DE ARMADURA ---
	# Aquí es donde brilla tener los stats separados.
	# Antes de restar vida, consultamos la defensa en HeroStats.
	
	var final_damage = amount
	
	if stats:
		# Ejemplo simple: La armadura reduce el daño directo
		# (Asegúrate de que no cure si la armadura es mayor que el daño)
		final_damage = max(0, amount - stats.armor)
	
	current_health -= final_damage

# Útil para power-ups de curación
func heal(amount: int) -> void:
	if not is_multiplayer_authority():
		return
	
	current_health += amount

func get_max_health() -> int:
	if stats and "max_health" in stats:
		return stats.max_health
	return base_max_health

func _on_stats_changed():
	#TO-DO To implement
	print("Level up!")

#region Computed Properties
## Retorna el porcentaje de vida actual (0.0 - 1.0).
## Útil para barras de vida y cálculos de UI.
func get_hp_percentage() -> float:
	if stats.max_hp <= 0.0:
		return 0.0
	return current_health / stats.max_hp


## Retorna true si el héroe está vivo (HP > 0).
func is_alive() -> bool:
	return current_health > 0.0


## Retorna true si el héroe está a máxima vida.
func is_full_hp() -> bool:
	return current_health >= stats.max_hp
#endregion

#region HP Modification Methods
## Aplica daño al héroe, respetando el límite mínimo de 0.
## @param amount: Cantidad de daño a aplicar (valor positivo)
## @return: Daño efectivo aplicado (puede ser menor si el HP era bajo)
func take_damage(amount: float) -> float:
	if amount <= 0.0:
		push_warning("HeroStats.take_damage: Se intentó aplicar daño con valor <= 0")
		return 0.0
	
	var damage_to_apply := minf(amount, current_health)  # No puede hacer más daño que el HP actual
	current_health -= damage_to_apply
	damage_taken.emit(damage_to_apply)
	return damage_to_apply


## Cura al héroe, respetando el límite máximo de max_hp.
## @param amount: Cantidad de curación a aplicar (valor positivo)
## @return: Curación efectiva aplicada (puede ser menor si ya estaba casi lleno)


## Restaura el HP al máximo instantáneamente.
## Útil para respawns o inicios de ronda.
func restore_full_hp() -> void:
	current_health = stats.max_hp


## Mata al héroe instantáneamente (HP = 0).
## Útil para mecánicas especiales o debug.
func kill() -> void:
	current_health = 0.0
#endregion
