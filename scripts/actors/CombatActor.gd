class_name CombatActor
extends CharacterBody2D
## Shared base for the player and every enemy. It owns the stat components and
## the one authoritative defence-resolution function, so the same guard button
## produces three graded outcomes by timing precision:
##   hold guard          -> BLOCK          (chip + stamina drain, can break)
##   press just in time   -> PERFECT BLOCK  (no damage, stagger, counter window)
##   press perfectly      -> PARRY          (no damage, long stagger, big counter)
## Parry/perfect are gated by `can_parry` so enemies only ever block.
##
## Expected scene tree:
##   CombatActor
##   ├─ HealthComponent / StaminaComponent / BalanceComponent
##   ├─ Hurtbox            (actor_path -> "..")
##   └─ Pivot (scale.x = facing)
##       ├─ Sprite
##       └─ Hitbox

enum Guard { NONE, BLOCKING }

@export var move_speed: float = 120.0
@export var gravity: float = 1200.0
@export var can_parry: bool = false

@export_group("Defence timing (seconds before impact)")
@export var parry_window: float = 0.10          ## tightest, best reward
@export var perfect_block_window: float = 0.18  ## looser, still no damage

@export_group("Defence rewards")
@export var parry_stagger: float = 0.9
@export var perfect_stagger: float = 0.5
@export var parry_counter_window: float = 0.5
@export var perfect_counter_window: float = 0.3

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

## Call every frame from the subclass with the current guard intent. A fresh
## press (NONE -> BLOCKING) timestamps the parry attempt.
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
func _on_hit_received(attack: AttackData, source: Node, damage_mult: float) -> void:
	if is_dead:
		return
	# No friendly fire between enemies.
	if source.is_in_group(&"enemy") and is_in_group(&"enemy"):
		return

	var attacker_side := int(signf(source.global_position.x - global_position.x))
	var attacker_in_front := attacker_side == facing
	var can_block := guard == Guard.BLOCKING and attacker_in_front \
			and not attack.beats_block and not attack.unblockable

	if can_block:
		var held := _now() - _guard_raised_at

		if can_parry and held <= parry_window:
			# PARRY — reflect, long stagger, big counter window. No cost.
			EventBus.attack_parried.emit(self, source)
			EventBus.camera_shake_requested.emit(0.5, 0.10)
			source.apply_stagger(parry_stagger)
			_open_counter(parry_counter_window)
			_on_parry(source)
			return

		if can_parry and held <= perfect_block_window:
			# PERFECT BLOCK — no damage, stagger, counter window.
			balance.apply_impact(attack.balance_damage * 0.1)
			EventBus.attack_perfect_blocked.emit(self, source)
			source.apply_stagger(perfect_stagger)
			_open_counter(perfect_counter_window)
			_on_perfect_block(source)
			return

		# NORMAL BLOCK — chip + drain. Guard breaks if stamina runs out.
		health.take_damage(attack.chip_damage * damage_mult)
		balance.apply_impact(attack.balance_damage * 0.5)
		if not stamina.spend(attack.balance_damage * 0.4):
			EventBus.guard_broken.emit(self)
			_on_guard_break(source)
		else:
			EventBus.attack_blocked.emit(source, self, attack)
			_on_block(source)
		return

	# CLEAN HIT.
	health.take_damage(attack.damage * damage_mult)
	balance.apply_impact(attack.balance_damage)
	velocity.x = attacker_side * attack.knockback   # pushed away from the source
	EventBus.actor_damaged.emit(self, attack.damage * damage_mult, source)
	EventBus.attack_landed.emit(source, self, attack)
	EventBus.camera_shake_requested.emit(attack.damage * 0.05, 0.12)
	_on_clean_hit(attack, source)

# --- Stagger: interrupts the current attack and locks the actor -------------
func apply_stagger(duration: float) -> void:
	if is_dead:
		return
	is_staggered = true
	velocity.x = 0.0
	_cancel_attack()
	get_tree().create_timer(duration).timeout.connect(_end_stagger)

func _end_stagger() -> void:
	if is_dead:
		return
	is_staggered = false
	_on_stagger_end()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# --- Overridable hooks (input/animation/AI live in subclasses) --------------
func _cancel_attack() -> void:
	pass
func _open_counter(_duration: float) -> void:
	pass
func _on_stagger_end() -> void:
	pass
func _on_clean_hit(_attack: AttackData, _source: Node) -> void:
	pass
func _on_block(_source: Node) -> void:
	pass
func _on_perfect_block(_source: Node) -> void:
	pass
func _on_parry(_source: Node) -> void:
	pass
func _on_guard_break(_source: Node) -> void:
	pass
func _on_balance_broken() -> void:
	EventBus.knockdown.emit(self)
func _on_died() -> void:
	is_dead = true
	hurtbox.set_deferred("monitoring", false)
	EventBus.actor_died.emit(self)
