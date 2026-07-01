class_name CombatActor
extends CharacterBody2D
## Shared base for the player and every enemy. It owns the stat components and
## the one authoritative defence-resolution function, so a block works the same
## whether you're holding the guard or an enemy is. Subclasses add input (Player)
## or perception+decisions (Enemy) and override the _on_* reaction hooks for
## their own animations.
##
## Expected scene tree (see the GDD "Scene contracts" section):
##   CombatActor (this script)
##   ├─ HealthComponent
##   ├─ StaminaComponent
##   ├─ BalanceComponent
##   ├─ Hurtbox            (actor_path -> ".."")
##   └─ Pivot              (Node2D; scale.x flipped by facing)
##       ├─ Sprite/AnimatedSprite
##       └─ Hitbox

enum Guard { NONE, BLOCKING }

@export var move_speed: float = 120.0
## How long after raising guard a block still counts as "perfect". Tight on
## purpose — perfect block is a read, not a default.
@export var perfect_block_window: float = 0.12
@export var gravity: float = 1200.0

@onready var health: HealthComponent = $HealthComponent
@onready var stamina: StaminaComponent = $StaminaComponent
@onready var balance: BalanceComponent = $BalanceComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var pivot: Node2D = $Pivot

var facing: int = 1
var guard: int = Guard.NONE
var is_dead: bool = false
var is_staggered: bool = false
var _guard_raised_at: float = -999.0

func _ready() -> void:
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	balance.balance_broken.connect(_on_balance_broken)

## Call every frame from the subclass with the current guard intent.
func set_guard(active: bool) -> void:
	if active and guard == Guard.NONE:
		_guard_raised_at = _now()
	guard = Guard.BLOCKING if active else Guard.NONE

func face_to(dir: int) -> void:
	if dir == 0:
		return
	facing = 1 if dir > 0 else -1
	pivot.scale.x = absf(pivot.scale.x) * facing

# --- Defence resolution: the single source of truth -------------------------
func _on_hit_received(attack: AttackData, source: Node) -> void:
	if is_dead:
		return
	# No friendly fire: enemies never damage other enemies.
	if source.is_in_group(&"enemy") and is_in_group(&"enemy"):
		return

	var attacker_side := int(signf(source.global_position.x - global_position.x))
	var attacker_in_front := attacker_side == facing
	var can_block := guard == Guard.BLOCKING and attacker_in_front \
			and not attack.beats_block and not attack.unblockable

	if can_block:
		var held := _now() - _guard_raised_at
		if held <= perfect_block_window:
			# Perfect block: no damage, attacker is exposed, we may counter.
			balance.apply_impact(attack.balance_damage * 0.1)
			EventBus.attack_perfect_blocked.emit(self, source)
			_on_perfect_block(source)
			return
		# Normal block: chip + drain. If we can't pay the stamina, guard breaks.
		health.take_damage(attack.chip_damage)
		balance.apply_impact(attack.balance_damage * 0.5)
		if not stamina.spend(attack.balance_damage * 0.4):
			EventBus.guard_broken.emit(self)
			_on_guard_break(source)
		else:
			EventBus.attack_blocked.emit(source, self, attack)
			_on_block(source)
		return

	# Clean hit.
	health.take_damage(attack.damage)
	balance.apply_impact(attack.balance_damage)
	velocity.x = attacker_side * attack.knockback   # pushed away from the source
	EventBus.actor_damaged.emit(self, attack.damage, source)
	EventBus.attack_landed.emit(source, self, attack)
	EventBus.camera_shake_requested.emit(attack.damage * 0.05, 0.12)
	_on_clean_hit(attack, source)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# --- Overridable reaction hooks (animation/feedback live in subclasses) ------
func _on_clean_hit(_attack: AttackData, _source: Node) -> void:
	pass

func _on_block(_source: Node) -> void:
	pass

func _on_perfect_block(_source: Node) -> void:
	pass

func _on_guard_break(_source: Node) -> void:
	pass

func _on_balance_broken() -> void:
	EventBus.knockdown.emit(self)

func _on_died() -> void:
	is_dead = true
	hurtbox.monitoring = false
	EventBus.actor_died.emit(self)
