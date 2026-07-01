class_name HealthComponent
extends Node
## Composable health. Attach to any actor; never let other scripts mutate
## current_health directly — always go through take_damage()/heal().

signal died
signal health_changed(current: float, maximum: float)

@export var max_health: float = 100.0

var current_health: float

func _ready() -> void:
	current_health = max_health

func take_damage(amount: float) -> void:
	if current_health <= 0.0:
		return
	current_health = clampf(current_health - amount, 0.0, max_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	if current_health <= 0.0:
		return
	current_health = clampf(current_health + amount, 0.0, max_health)
	health_changed.emit(current_health, max_health)

func is_alive() -> bool:
	return current_health > 0.0

func fraction() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0
