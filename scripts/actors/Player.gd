class_name Player
extends CombatActor
## The lone warrior. Two modes: TRAVERSAL (walk/run/sneak) and COMBAT (raised
## guard, attacks). Attacks run off each attack's frame data. Guarding is
## timing-graded (block / perfect block / parry) via CombatActor, and a
## successful parry/perfect block opens a COUNTER window: your next attack comes
## out faster, hits harder, and costs no stamina.

@export var run_multiplier: float = 1.7
@export var sneak_multiplier: float = 0.5
@export var walk_noise_radius: float = 90.0
@export var run_noise_radius: float = 220.0

@export_group("Counter")
@export var counter_damage_mult: float = 1.6
@export var counter_startup_scale: float = 0.4

@export_group("Attacks")
@export var light_punch: AttackData
@export var heavy_punch: AttackData
@export var front_kick: AttackData
@export var roundhouse: AttackData
@export var sweep: AttackData

@onready var hitbox: Hitbox = $Pivot/Hitbox
@onready var anim: AnimationTree = $AnimationTree

var _attacking: bool = false
var _counter_ready: bool = false

func _ready() -> void:
	super._ready()
	can_parry = true
	add_to_group(&"player")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity.y += gravity * delta

	if is_staggered:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		move_and_slide()
		return

	set_guard(Input.is_action_pressed("guard") and not _attacking)

	if not _attacking:
		_handle_movement()
		_handle_attacks()
	else:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)

	move_and_slide()

func _handle_movement() -> void:
	var dir := Input.get_axis("move_left", "move_right")
	var speed := move_speed
	var noise := 0.0

	if Input.is_action_pressed("run"):
		speed *= run_multiplier
		noise = run_noise_radius
	elif Input.is_action_pressed("sneak"):
		speed *= sneak_multiplier
	elif absf(dir) > 0.0:
		noise = walk_noise_radius

	velocity.x = dir * speed

	if guard == Guard.NONE and dir != 0.0:
		face_to(int(signf(dir)))

	if noise > 0.0 and absf(velocity.x) > 1.0:
		EventBus.noise_emitted.emit(global_position, noise, self)

func _handle_attacks() -> void:
	if Input.is_action_just_pressed("light_punch"):
		_perform(light_punch)
	elif Input.is_action_just_pressed("heavy_punch"):
		_perform(heavy_punch)
	elif Input.is_action_just_pressed("front_kick"):
		_perform(front_kick)
	elif Input.is_action_just_pressed("roundhouse"):
		_perform(roundhouse)
	elif Input.is_action_just_pressed("sweep"):
		_perform(sweep)

func _perform(attack: AttackData) -> void:
	if attack == null or _attacking:
		return

	var countering := _counter_ready
	var mult := 1.0
	if countering:
		mult = counter_damage_mult
		_counter_ready = false        # spend the window
	elif not stamina.spend(attack.stamina_cost):
		return                        # too tired

	_attacking = true
	velocity.x = 0.0

	var startup := attack.startup_time()
	if countering:
		startup *= counter_startup_scale

	await get_tree().create_timer(startup).timeout
	if _interrupted():
		return

	hitbox.activate(attack, self, facing, mult)
	await get_tree().create_timer(attack.active_time()).timeout
	hitbox.deactivate()
	if _interrupted():
		return

	await get_tree().create_timer(attack.recovery_time()).timeout
	_attacking = false

## True if the attack was cancelled (death or stagger via _cancel_attack).
func _interrupted() -> bool:
	if is_dead or not _attacking:
		hitbox.deactivate()
		_attacking = false
		return true
	return false

# --- Hooks -------------------------------------------------------------------
func _cancel_attack() -> void:
	_attacking = false
	hitbox.deactivate()

func _open_counter(duration: float) -> void:
	_counter_ready = true
	get_tree().create_timer(duration).timeout.connect(func(): _counter_ready = false)
