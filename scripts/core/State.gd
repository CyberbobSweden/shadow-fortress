class_name State
extends Node
## Base for every state. Override what you need. Call
## state_machine.transition_to(&"name") to move on.

var state_machine: StateMachine

func enter(_msg: Dictionary = {}) -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
