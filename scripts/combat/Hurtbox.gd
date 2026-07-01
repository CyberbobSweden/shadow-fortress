class_name Hurtbox
extends Area2D
## The receiving volume. It detects an incoming Hitbox and forwards the raw hit
## to the owning actor — it does NOT decide damage. All defence logic (block,
## perfect block, parry, knockback direction) lives on CombatActor so player
## and enemy share one rule set.

signal hit_received(attack: AttackData, source: Node)

@export var actor_path: NodePath

var actor: Node

func _ready() -> void:
	monitorable = true
	monitoring = true
	actor = get_node_or_null(actor_path)
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if not (area is Hitbox):
		return
	var hb := area as Hitbox
	if hb.attack == null or hb.source == actor:
		return    ## ignore stale boxes and self-hits
	hit_received.emit(hb.attack, hb.source)
