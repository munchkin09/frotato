## HeroStats.gd
## Resource personalizado para definir las estadísticas base del héroe.
## Permite crear diferentes configuraciones de héroes y ajustar el balance fácilmente.
## Uso: Crear instancias .tres en el editor y asignarlas a los nodos de héroes.

class_name HeroStats
extends Resource

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

#region Base Stats
## Vida máxima del héroe. Define el límite superior de current_hp.
@export_range(1.0, 1000.0, 1.0) var max_hp: float = 100.0:
	set(value):
		max_hp = maxf(1.0, value)  # Prevenir valores inválidos
		# Si current_hp excede el nuevo máximo, ajustarlo
		if current_hp > max_hp:
			current_hp = max_hp

## Vida actual del héroe. Siempre entre 0 y max_hp.
@export_range(0.0, 1000.0, 1.0) var current_hp: float = 100.0:
	set(value):
		var old_hp := current_hp
		current_hp = clampf(value, 0.0, max_hp)
		if current_hp != old_hp:
			hp_changed.emit(current_hp, max_hp)
			if current_hp <= 0.0:
				hero_died.emit()

## Velocidad de movimiento del héroe en píxeles por segundo.
@export_range(50.0, 800.0, 10.0) var move_speed: float = 300.0

## Rango de recolección de items en píxeles.
## Los materiales/oro dentro de este rango serán atraídos hacia el héroe.
@export_range(10.0, 500.0, 5.0) var pickup_range: float = 50.0

## Daño base que inflige el héroe con sus ataques.
## Se usa como multiplicador base para el sistema de armas.
@export_range(1.0, 500.0, 1.0) var base_damage: float = 10.0
#endregion

#region Computed Properties
## Retorna el porcentaje de vida actual (0.0 - 1.0).
## Útil para barras de vida y cálculos de UI.
func get_hp_percentage() -> float:
	if max_hp <= 0.0:
		return 0.0
	return current_hp / max_hp


## Retorna true si el héroe está vivo (HP > 0).
func is_alive() -> bool:
	return current_hp > 0.0


## Retorna true si el héroe está a máxima vida.
func is_full_hp() -> bool:
	return current_hp >= max_hp
#endregion

#region HP Modification Methods
## Aplica daño al héroe, respetando el límite mínimo de 0.
## @param amount: Cantidad de daño a aplicar (valor positivo)
## @return: Daño efectivo aplicado (puede ser menor si el HP era bajo)
func take_damage(amount: float) -> float:
	if amount <= 0.0:
		push_warning("HeroStats.take_damage: Se intentó aplicar daño con valor <= 0")
		return 0.0
	
	var damage_to_apply := minf(amount, current_hp)  # No puede hacer más daño que el HP actual
	current_hp -= damage_to_apply
	damage_taken.emit(damage_to_apply)
	return damage_to_apply


## Cura al héroe, respetando el límite máximo de max_hp.
## @param amount: Cantidad de curación a aplicar (valor positivo)
## @return: Curación efectiva aplicada (puede ser menor si ya estaba casi lleno)
func heal(amount: float) -> float:
	if amount <= 0.0:
		push_warning("HeroStats.heal: Se intentó curar con valor <= 0")
		return 0.0
	
	var hp_missing := max_hp - current_hp
	var heal_to_apply := minf(amount, hp_missing)  # No puede curar más de lo que falta
	current_hp += heal_to_apply
	healed.emit(heal_to_apply)
	return heal_to_apply


## Restaura el HP al máximo instantáneamente.
## Útil para respawns o inicios de ronda.
func restore_full_hp() -> void:
	current_hp = max_hp


## Mata al héroe instantáneamente (HP = 0).
## Útil para mecánicas especiales o debug.
func kill() -> void:
	current_hp = 0.0
#endregion

#region Initialization
## Inicializa las estadísticas con HP completo.
## Llamar esto al spawnear el héroe para asegurar estado inicial correcto.
func initialize() -> void:
	current_hp = max_hp


## Crea una copia duplicada de este Resource.
## Útil cuando múltiples héroes usan la misma configuración base
## pero necesitan trackear su propio HP independientemente.
func create_instance() -> HeroStats:
	var instance := duplicate() as HeroStats
	instance.initialize()
	return instance
#endregion
