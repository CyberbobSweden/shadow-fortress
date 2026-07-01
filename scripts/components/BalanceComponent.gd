class_name BalanceComponent
extends Node
## Balance is poise. Heavy hits and sweeps drain it; when it empties the actor
## is knocked down (a vulnerable get-up window). It recovers faster than
## stamina, so being staggered is a momentary danger, not a death sentence.

signal balance_changed(current: float, maximum: float)
signal balance_broken

@export var max_balance: float = 100.0
@export var recover_per_second: float = 30.0
@export var recover_delay: float = 0.4

var current_balance: float
var _recover_cooldown: float = 0.0

func _ready() -> void:
	current_balance = max_balance

func _process(delta: float) -> void:
	if _recover_cooldown > 0.0:
		_recover_cooldown -= delta
		return
	if current_balance < max_balance:
		current_balance = minf(current_balance + recover_per_second * delta, max_balance)
		balance_changed.emit(current_balance, max_balance)

func apply_impact(amount: float) -> void:
	if current_balance <= 0.0:
		return
	current_balance = maxf(current_balance - amount, 0.0)
	_recover_cooldown = recover_delay
	balance_changed.emit(current_balance, max_balance)
	if current_balance <= 0.0:
		balance_broken.emit()

func reset() -> void:
	current_balance = max_balance
	balance_changed.emit(current_balance, max_balance)
