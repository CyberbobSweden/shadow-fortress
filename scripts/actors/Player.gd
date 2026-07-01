class_name Player
extends CombatActor
## The lone warrior. Two modes: TRAVERSAL (walk/run/sneak, used to explore and
## avoid guards) and COMBAT (raised guard, attacks). Attacks drive the hitbox
## directly from each attack's frame data, so a Heavy Punch genuinely has the
## long recovery the designer authored — whiff one and you will get punished.
##
## Attack resources are assigned in the inspector (drag .tres files in), which
## keeps tuning out of code entirely.

@export var run_multiplier: float = 1.7
@export var sneak_multiplier: float = 0.5
## Moving normally / running makes noise enemies can hear; sneaking is quiet.
@export var walk_noise_radius: float = 90.0
@export var run_noise_radius: float = 220.0

@export_group("Attacks")
@export var light_punch: AttackData
@export var heavy_punch: AttackData
@export var front_kick: AttackData
@export var roundhouse: AttackData
@export var sweep: AttackData

@onready var hitbox: Hitbox = $Pivot/Hitbox
@onready var anim: AnimationTree = $AnimationTree

var _attacking: bool = false
var _counter_window: bool = false

func _ready() -> void:
	super._ready()
	add_to_group(&"player")

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += gravity * delta

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
	else:
		if absf(dir) > 0.0:
			noise = walk_noise_radius

	velocity.x = dir * speed

	# Don't turn while guarding — you keep facing the threat.
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

## Runs one attack's full timeline: startup -> active (hitbox on) -> recovery.
## Using awaited timers keeps this readable; in production the active window is
## better driven by an AnimationPlayer call-method track so the hitbox is
## frame-locked to the sprite. Both are wired the same way.
func _perform(attack: AttackData) -> void:
	if attack == null or _attacking:
		return
	if not stamina.spend(attack.stamina_cost):
		return   # too tired — feedback handled by the HUD/stamina flash

	_attacking = true
	velocity.x = 0.0

	await get_tree().create_timer(attack.startup_time()).timeout
	if is_dead:
		_attacking = false
		return

	hitbox.activate(attack, self, facing)
	await get_tree().create_timer(attack.active_time()).timeout
	hitbox.deactivate()

	await get_tree().create_timer(attack.recovery_time()).timeout
	_attacking = false

# --- Reaction hooks ----------------------------------------------------------
func _on_perfect_block(_source: Node) -> void:
	# Reward: a brief window where the next attack is faster/stronger.
	_counter_window = true
	EventBus.camera_shake_requested.emit(0.4, 0.08)
	get_tree().create_timer(0.25).timeout.connect(func(): _counter_window = false)

func _on_clean_hit(attack: AttackData, _source: Node) -> void:
	if attack.height == AttackData.Height.LOW:
		pass # play stumble; left for the animation pass
