class_name Hitbox
extends Area2D
## The offensive volume. Its collision shape is disabled by default and enabled
## only during an attack's active frames. Toggling the shape (not a flag)
## reliably generates area_entered on the defender's Hurtbox even when the two
## actors already overlap.
##
## Carries the AttackData, the attacker, and an optional damage multiplier
## (used by counter attacks). Place under the actor's flip Pivot so it mirrors.

var attack: AttackData
var source: Node          ## the attacking CombatActor
var facing: int = 1       ## 1 = right, -1 = left
var damage_mult: float = 1.0

@onready var _shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	monitorable = true
	monitoring = false
	if _shape:
		_shape.disabled = true

func activate(p_attack: AttackData, p_source: Node, p_facing: int, p_mult: float = 1.0) -> void:
	attack = p_attack
	source = p_source
	facing = p_facing
	damage_mult = p_mult
	if _shape:
		_shape.set_deferred("disabled", false)

func deactivate() -> void:
	if _shape:
		_shape.set_deferred("disabled", true)
	attack = null
	damage_mult = 1.0
