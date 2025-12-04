## HeroStats.gd
## Resource personalizado para definir las estadísticas base del héroe.
## Permite crear diferentes configuraciones de héroes y ajustar el balance fácilmente.
## Uso: Crear instancias .tres en el editor y asignarlas a los nodos de héroes.

class_name HeroStats
extends Resource

#region Base Stats
## Vida máxima del héroe. Define el límite superior de vida del personaje(current_health se gestiona en HealthComponent).
@export_range(1.0, 1000.0, 1.0) var max_hp: float = 100.0:
	set(value):
		max_hp = maxf(1.0, value)  # Prevenir valores inválidos

## Velocidad de movimiento del héroe en píxeles por segundo.
@export_range(50.0, 800.0, 10.0) var move_speed: float = 300.0

## Rango de recolección de items en píxeles.
## Los materiales/oro dentro de este rango serán atraídos hacia el héroe.
@export_range(10.0, 500.0, 5.0) var pickup_range: float = 50.0

## Daño base que inflige el héroe con sus ataques.
## Se usa como multiplicador base para el sistema de armas.
@export_range(1.0, 500.0, 1.0) var base_damage: float = 10.0

@export_range(-300.0,300.0, 1.0) var dodge_prob: float = 0.0

@export_range(-300.0,300.0, 1.0) var damage_modifier: float = 0.0

@export var luck: float = 5.0

@export var level: int

@export var exp: float
#endregion


#region Initialization
## Inicializa las estadísticas con HP completo.
## Llamar esto al spawnear el héroe para asegurar estado inicial correcto.
func initialize() -> void:
	level = 1
	exp = 0.0
	
## Crea una copia duplicada de este Resource.
## Útil cuando múltiples héroes usan la misma configuración base
## pero necesitan trackear su propio HP independientemente.
func create_instance() -> HeroStats:
	var instance := duplicate() as HeroStats
	instance.initialize()
	return instance
#endregion
