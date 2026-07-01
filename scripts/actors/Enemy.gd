class_name Enemy
extends CombatActor
## An enemy that thinks. It patrols, investigates sounds, engages on sight, and
## only commits to attacks when the Encounter coordinator grants it a token —
## so groups pressure you in turns instead of all at once. Low morale (allies
## down or its own health gone) can make it call for help or flee.
##
## Tune everything in the inspector: vision, hearing, spacing, aggression,
## courage, and the attack list (drag in the same .tres files the player uses).

enum AIState {
	PATROL, IDLE_GUARD, INVESTIGATE, ENGAGE, ATTACK,
	DEFEND, REPOSITION, FLEE, SEARCH, STAGGER, KNOCKDOWN, DEAD
}

@export_group("Perception")
@export var vision_range: float = 280.0
@export var vision_angle_deg: float = 75.0
@export var hearing_range: float = 200.0

@export_group("Spacing")
@export var attack_range: float = 80.0
@export var preferred_range: float = 130.0

@export_group("Personality")
@export_range(0.0, 1.0) var aggression: float = 0.5  ## how readily it commits
@export_range(0.0, 1.0) var courage: float = 0.6     ## morale floor before it flees

@export_group("Behaviour")
@export var patrol_points: Array[Vector2] = []
@export var search_duration: float = 4.0
@export var attacks: Array[AttackData] = []

@onready var hitbox: Hitbox = $Pivot/Hitbox

var state: int = AIState.PATROL
var last_known_pos: Vector2
var _patrol_index: int = 0
var _state_timer: float = 0.0
var _holds_token: bool = false
var _attacking: bool = false

func _ready() -> void:
	super._ready()
	add_to_group(&"enemy")
	EventBus.noise_emitted.connect(_on_noise)
	EventBus.alarm_raised.connect(_on_alarm)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	_state_timer = maxf(_state_timer - delta, 0.0)

	match state:
		AIState.PATROL: _do_patrol(delta)
		AIState.IDLE_GUARD: _do_idle_guard()
		AIState.INVESTIGATE: _do_investigate(delta)
		AIState.ENGAGE: _do_engage(delta)
		AIState.ATTACK: _do_attack()
		AIState.DEFEND: _do_defend(delta)
		AIState.REPOSITION: _do_reposition(delta)
		AIState.FLEE: _do_flee(delta)
		AIState.SEARCH: _do_search(delta)
		AIState.STAGGER, AIState.KNOCKDOWN:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)

	move_and_slide()

# --- State transitions -------------------------------------------------------
func _set_state(s: int, timer: float = 0.0) -> void:
	# Leaving an attacking/engaged state returns the shared attack token.
	if s != AIState.ATTACK and s != AIState.ENGAGE:
		_release_token()
	state = s
	_state_timer = timer

func _release_token() -> void:
	if _holds_token:
		Encounter.release_token()
		_holds_token = false

# --- Perception --------------------------------------------------------------
func _player() -> Node2D:
	return get_tree().get_first_node_in_group(&"player") as Node2D

func _can_see_player() -> bool:
	var p := _player()
	if p == null or p.is_dead:
		return false
	var to_p := p.global_position - global_position
	if to_p.length() > vision_range:
		return false
	var fwd := Vector2(facing, 0.0)
	# Within the cone? (Half-angle on each side of facing.)
	return absf(fwd.angle_to(to_p.normalized())) <= deg_to_rad(vision_angle_deg) * 0.5

func _on_noise(pos: Vector2, radius: float, source: Node) -> void:
	if source == self or is_dead:
		return
	if global_position.distance_to(pos) <= radius + hearing_range:
		last_known_pos = pos
		if state == AIState.PATROL or state == AIState.IDLE_GUARD:
			_set_state(AIState.INVESTIGATE)

func _on_alarm(pos: Vector2) -> void:
	if is_dead:
		return
	last_known_pos = pos
	if state in [AIState.PATROL, AIState.IDLE_GUARD, AIState.INVESTIGATE]:
		_set_state(AIState.ENGAGE)

func _morale() -> float:
	# Health is the main driver; outnumbered-and-hurt enemies break first.
	return health.fraction()

# --- Behaviours --------------------------------------------------------------
func _do_patrol(delta: float) -> void:
	if _can_see_player():
		_alert(); return
	if patrol_points.is_empty():
		_set_state(AIState.IDLE_GUARD); return
	var target_pos: Vector2 = patrol_points[_patrol_index]
	_move_toward_x(target_pos.x, move_speed * 0.6)
	if absf(global_position.x - target_pos.x) < 8.0:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		_set_state(AIState.IDLE_GUARD, 1.5)

func _do_idle_guard() -> void:
	velocity.x = 0.0
	if _can_see_player():
		_alert(); return
	if _state_timer <= 0.0:
		_set_state(AIState.PATROL)

func _do_investigate(delta: float) -> void:
	if _can_see_player():
		_alert(); return
	_face_point(last_known_pos)
	_move_toward_x(last_known_pos.x, move_speed * 0.8)
	if absf(global_position.x - last_known_pos.x) < 12.0:
		_set_state(AIState.SEARCH, search_duration)

func _do_search(delta: float) -> void:
	velocity.x = 0.0
	if _can_see_player():
		_alert(); return
	# Look around, then give up and resume the patrol.
	if _state_timer <= 0.0:
		_set_state(AIState.PATROL)

func _alert() -> void:
	var p := _player()
	if p:
		last_known_pos = p.global_position
		EventBus.player_spotted.emit(self)
	_set_state(AIState.ENGAGE)

func _do_engage(delta: float) -> void:
	var p := _player()
	if p == null or p.is_dead:
		_set_state(AIState.SEARCH, search_duration); return

	if _morale() < (1.0 - courage):
		# Hurt and shaken: try to raise the alarm, else break and run.
		EventBus.alarm_raised.emit(global_position)
		if randf() > courage:
			_set_state(AIState.FLEE, 2.0); return

	_face_point(p.global_position)
	var dist := absf(p.global_position.x - global_position.x)

	if dist <= attack_range:
		# In range: try to grab a token and strike, otherwise defend/space.
		if not _holds_token:
			_holds_token = Encounter.request_token()
		if _holds_token and randf() < aggression:
			_set_state(AIState.ATTACK); return
		else:
			_set_state(AIState.DEFEND, 0.5); return
	elif dist > preferred_range:
		_move_toward_x(p.global_position.x, move_speed)  # close the gap
	else:
		# Hover at the edge, baiting; occasionally reposition to feel alive.
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		if randf() < 0.01:
			_set_state(AIState.REPOSITION, 0.5)

func _do_attack() -> void:
	velocity.x = 0.0
	if not _attacking:
		_perform(_pick_attack())

func _do_defend(delta: float) -> void:
	var p := _player()
	if p == null:
		_set_state(AIState.SEARCH, search_duration); return
	_face_point(p.global_position)
	set_guard(true)
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	if _state_timer <= 0.0:
		set_guard(false)
		_set_state(AIState.ENGAGE)

func _do_reposition(delta: float) -> void:
	var p := _player()
	if p == null:
		_set_state(AIState.SEARCH, search_duration); return
	# Side-step to break the player's rhythm, then re-engage.
	var away := -signf(p.global_position.x - global_position.x)
	velocity.x = away * move_speed * 0.7
	if _state_timer <= 0.0:
		_set_state(AIState.ENGAGE)

func _do_flee(delta: float) -> void:
	var p := _player()
	if p:
		var away := -signf(p.global_position.x - global_position.x)
		velocity.x = away * move_speed * run_speed_mult()
		_face_point(global_position + Vector2(away, 0.0))
	if _state_timer <= 0.0:
		# Re-evaluate: if it found nerve again, come back; otherwise keep going.
		_set_state(AIState.ENGAGE if _morale() > (1.0 - courage) else AIState.FLEE, 2.0)

func run_speed_mult() -> float:
	return 1.6

# --- Attack execution (mirrors the player's frame-driven model) --------------
func _pick_attack() -> AttackData:
	if attacks.is_empty():
		return null
	return attacks[randi() % attacks.size()]

func _perform(attack: AttackData) -> void:
	if attack == null or _attacking:
		_set_state(AIState.ENGAGE); return
	if not stamina.spend(attack.stamina_cost):
		_set_state(AIState.DEFEND, 0.6); return

	_attacking = true
	await get_tree().create_timer(attack.startup_time()).timeout
	if is_dead:
		_attacking = false; return
	hitbox.activate(attack, self, facing)
	await get_tree().create_timer(attack.active_time()).timeout
	hitbox.deactivate()
	await get_tree().create_timer(attack.recovery_time()).timeout
	_attacking = false
	if not is_dead:
		_set_state(AIState.ENGAGE)

# --- Movement helpers --------------------------------------------------------
func _move_toward_x(target_x: float, speed: float) -> void:
	var dir := signf(target_x - global_position.x)
	velocity.x = dir * speed
	face_to(int(dir))

func _face_point(p: Vector2) -> void:
	face_to(int(signf(p.x - global_position.x)))

# --- Reactions ---------------------------------------------------------------
func _on_clean_hit(_attack: AttackData, _source: Node) -> void:
	# Getting hit interrupts the current plan and forces a brief stagger.
	_attacking = false
	hitbox.deactivate()
	_set_state(AIState.STAGGER, 0.3)
	get_tree().create_timer(0.3).timeout.connect(func():
		if not is_dead and state == AIState.STAGGER:
			_set_state(AIState.ENGAGE))

func _on_balance_broken() -> void:
	super._on_balance_broken()
	_attacking = false
	hitbox.deactivate()
	_set_state(AIState.KNOCKDOWN, 1.2)
	get_tree().create_timer(1.2).timeout.connect(func():
		if not is_dead:
			balance.reset()
			_set_state(AIState.ENGAGE))

func _on_died() -> void:
	super._on_died()
	_release_token()
	state = AIState.DEAD
	# A death lowers nearby allies' morale via the alarm channel.
	EventBus.alarm_raised.emit(global_position)
