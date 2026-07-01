class_name Hitbox
extends Area2D
## The offensive volume. Its collision shape is disabled by default and enabled
## only during an attack's active frames. Toggling the shape (rather than a
## flag) reliably generates area_entered on the defender's Hurtbox even when the
## two actors are already standing inside each other's reach.
##
## It carries the AttackData and the attacker so the Hurtbox can resolve the
## hit. Place it under the actor's flip Pivot so it mirrors with facing.

var attack: AttackData
var source: Node          ## the attacking CombatActor
var facing: int = 1       ## 1 = right, -1 = left

@onready var _shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	monitorable = true
	monitoring = false
	if _shape:
		_shape.disabled = true

func activate(p_attack: AttackData, p_source: Node, p_facing: int) -> void:
	attack = p_attack
	source = p_source
	facing = p_facing
	if _shape:
		_shape.set_deferred("disabled", false)

func deactivate() -> void:
	if _shape:
		_shape.set_deferred("disabled", true)
	attack = null
