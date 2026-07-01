class_name StaminaComponent
extends Node
## Stamina gates how much you can act. Attacking and blocking spend it; it
## regenerates after a short delay of not spending. At zero, guard breaks and
## attacks come out weak. This is the pacing valve that stops button-mashing.

signal stamina_changed(current: float, maximum: float)
signal exhausted

@export var max_stamina: float = 100.0
@export var regen_per_second: float = 18.0
## Seconds to wait after the last spend before regen resumes.
@export var regen_delay: float = 0.6

var current_stamina: float
var _regen_cooldown: float = 0.0

func _ready() -> void:
	current_stamina = max_stamina

func _process(delta: float) -> void:
	if _regen_cooldown > 0.0:
		_regen_cooldown -= delta
		return
	if current_stamina < max_stamina:
		current_stamina = minf(current_stamina + regen_per_second * delta, max_stamina)
		stamina_changed.emit(current_stamina, max_stamina)

func can_spend(amount: float) -> bool:
	return current_stamina >= amount

## Returns false (and spends nothing) if too tired. Callers decide what a
## failed spend means — usually a weak attack or no attack at all.
func spend(amount: float) -> bool:
	if current_stamina < amount:
		return false
	current_stamina -= amount
	_regen_cooldown = regen_delay
	stamina_changed.emit(current_stamina, max_stamina)
	if current_stamina <= 0.0:
		exhausted.emit()
	return true

func fraction() -> float:
	return current_stamina / max_stamina if max_stamina > 0.0 else 0.0
