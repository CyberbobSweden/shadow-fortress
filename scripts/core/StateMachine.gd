class_name StateMachine
extends Node
## Generic state machine. Add State children, point initial_state at one, and
## the machine drives enter/exit/update. Used for the player's movement+combat
## states and any actor that wants clean, debuggable behaviour transitions.

signal state_changed(state_name: StringName)

@export var initial_state: NodePath

var current_state: State
var _states: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is State:
			_states[child.name] = child
			(child as State).state_machine = self
	if not initial_state.is_empty():
		current_state = get_node(initial_state) as State
		current_state.enter()

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	if not _states.has(state_name):
		push_warning("StateMachine: unknown state '%s'" % state_name)
		return
	if current_state:
		current_state.exit()
	current_state = _states[state_name]
	current_state.enter(msg)
	state_changed.emit(state_name)
