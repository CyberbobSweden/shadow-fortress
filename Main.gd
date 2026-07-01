extends Node2D
## VERTICAL SLICE — built entirely in code so it runs without hand-authored
## scene files. One screen of Mountain Pass: the warrior versus two thinking
## guards, with the full combat + AI + token systems from the foundation.
##
## Visuals are intentionally blockout (coloured rectangles). Every SYSTEM is
## real — drop in sprite sheets later and the feel is already here.
##
## Controls:  A/D move · Shift run · Ctrl sneak · K guard
##            J light · U heavy · I front kick · O roundhouse · L sweep

const FLOOR_TOP := 760.0
const ATTACK_LAYER := 1 << 7   # bit used only by hit/hurtboxes

var player: Player
var _enemies_alive := 0

# HUD refs
var _health_fill: ColorRect
var _stamina_fill: ColorRect
var _banner: Label

func _ready() -> void:
	_build_background()
	_build_floor()
	var atk := _build_attacks()

	player = _build_player(atk, Vector2(480, FLOOR_TOP - 120))
	add_child(player)

	_spawn_enemy(atk, Vector2(1150, FLOOR_TOP - 120), [Vector2(1000, 0), Vector2(1350, 0)], 0.55, 0.6)
	_spawn_enemy(atk, Vector2(1500, FLOOR_TOP - 120), [Vector2(1380, 0), Vector2(1650, 0)], 0.4, 0.7)

	_build_hud()

	EventBus.actor_died.connect(_on_actor_died)

# --- Attacks (frame data straight from the design doc table) -----------------
func _build_attacks() -> Dictionary:
	return {
		&"light": _make_attack(&"light_punch", "Light Punch", AttackData.Height.MID, 6, 3, 10, 6, 1, 4, 8, 40, 1.1),
		&"heavy": _make_attack(&"heavy_punch", "Heavy Punch", AttackData.Height.MID, 12, 4, 20, 14, 3, 10, 18, 80, 1.2),
		&"front": _make_attack(&"front_kick", "Front Kick", AttackData.Height.MID, 10, 4, 16, 10, 2, 14, 14, 120, 1.6),
		&"round": _make_attack(&"roundhouse", "Roundhouse", AttackData.Height.HIGH, 16, 5, 26, 20, 5, 22, 24, 140, 1.7),
		&"sweep": _make_attack(&"sweep", "Sweep", AttackData.Height.LOW, 12, 4, 22, 8, 2, 30, 16, 60, 1.3),
	}

func _make_attack(id: StringName, disp: String, height: int,
		su: int, ac: int, re: int, dmg: float, chip: float, bal: float,
		stam: float, kb: float, reach: float) -> AttackData:
	var a := AttackData.new()
	a.id = id
	a.display_name = disp
	a.height = height
	a.startup_frames = su
	a.active_frames = ac
	a.recovery_frames = re
	a.damage = dmg
	a.chip_damage = chip
	a.balance_damage = bal
	a.stamina_cost = stam
	a.knockback = kb
	a.reach = reach
	return a

# --- Actor construction ------------------------------------------------------
func _build_player(atk: Dictionary, pos: Vector2) -> Player:
	var p := Player.new()
	p.position = pos
	p.collision_layer = 1 << 1
	p.collision_mask = 1 << 0        # collides with the floor only
	_attach_common_nodes(p, Color(0.45, 0.7, 1.0))   # cool blue warrior

	p.light_punch = atk[&"light"]
	p.heavy_punch = atk[&"heavy"]
	p.front_kick = atk[&"front"]
	p.roundhouse = atk[&"round"]
	p.sweep = atk[&"sweep"]

	# AnimationTree placeholder so the @onready resolves cleanly (kept inactive).
	var tree := AnimationTree.new()
	tree.name = "AnimationTree"
	tree.active = false
	p.add_child(tree)

	# Camera follows the warrior.
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.position = Vector2(0, -80)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	p.add_child(cam)
	cam.make_current()
	return p

func _spawn_enemy(atk: Dictionary, pos: Vector2, patrol: Array,
		aggression: float, courage: float) -> void:
	var e := Enemy.new()
	e.position = pos
	e.collision_layer = 1 << 1
	e.collision_mask = 1 << 0
	_attach_common_nodes(e, Color(0.85, 0.35, 0.35))   # red guard

	var typed_patrol: Array[Vector2] = []
	for v in patrol:
		typed_patrol.append(v)
	e.patrol_points = typed_patrol

	var typed_attacks: Array[AttackData] = [atk[&"light"], atk[&"heavy"], atk[&"front"]]
	e.attacks = typed_attacks
	e.aggression = aggression
	e.courage = courage
	e.move_speed = 110.0

	add_child(e)
	_enemies_alive += 1

## Builds the shared node tree the actor scripts expect (component children,
## hurtbox, pivot + sprite + hitbox, body collision).
func _attach_common_nodes(actor: CharacterBody2D, body_color: Color) -> void:
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = 100.0
	actor.add_child(health)

	var stamina := StaminaComponent.new()
	stamina.name = "StaminaComponent"
	actor.add_child(stamina)

	var balance := BalanceComponent.new()
	balance.name = "BalanceComponent"
	actor.add_child(balance)

	# Body collision.
	var body_cs := CollisionShape2D.new()
	var body_shape := RectangleShape2D.new()
	body_shape.size = Vector2(50, 100)
	body_cs.shape = body_shape
	actor.add_child(body_cs)

	# Hurtbox (receives hits) — covers the body.
	var hurt := Hurtbox.new()
	hurt.name = "Hurtbox"
	hurt.actor_path = NodePath("..")
	hurt.collision_layer = 0
	hurt.collision_mask = ATTACK_LAYER
	var hurt_cs := CollisionShape2D.new()
	var hurt_shape := RectangleShape2D.new()
	hurt_shape.size = Vector2(46, 96)
	hurt_cs.shape = hurt_shape
	hurt.add_child(hurt_cs)
	actor.add_child(hurt)

	# Pivot mirrors with facing.
	var pivot := Node2D.new()
	pivot.name = "Pivot"
	actor.add_child(pivot)

	# Blockout sprite.
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-25, -50), Vector2(25, -50), Vector2(25, 50), Vector2(-25, 50)
	])
	poly.color = body_color
	pivot.add_child(poly)
	# A small notch marks the facing direction.
	var nose := Polygon2D.new()
	nose.polygon = PackedVector2Array([
		Vector2(25, -10), Vector2(40, 0), Vector2(25, 10)
	])
	nose.color = body_color.lightened(0.3)
	pivot.add_child(nose)

	# Hitbox (offensive) — sits in front, flips with the pivot.
	var hit := Hitbox.new()
	hit.name = "Hitbox"
	hit.position = Vector2(48, -10)
	hit.collision_layer = ATTACK_LAYER
	hit.collision_mask = 0
	var hit_cs := CollisionShape2D.new()
	var hit_shape := RectangleShape2D.new()
	hit_shape.size = Vector2(56, 50)
	hit_cs.shape = hit_shape
	hit.add_child(hit_cs)
	pivot.add_child(hit)

# --- World -------------------------------------------------------------------
func _build_floor() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1 << 0
	floor_body.position = Vector2(0, FLOOR_TOP + 40)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(6000, 80)
	cs.shape = shape
	cs.position = Vector2(2000, 0)
	floor_body.add_child(cs)
	add_child(floor_body)

	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([
		Vector2(-1000, FLOOR_TOP), Vector2(5000, FLOOR_TOP),
		Vector2(5000, 1200), Vector2(-1000, 1200)
	])
	ground.color = Color(0.12, 0.13, 0.17)
	add_child(ground)

func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.10)   # cold night sky
	bg.size = Vector2(1920, 1080)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	layer.add_child(bg)

# --- HUD ---------------------------------------------------------------------
func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	_health_fill = _make_bar(hud, Vector2(40, 40), Color(0.8, 0.2, 0.2), "LIV")
	_stamina_fill = _make_bar(hud, Vector2(40, 80), Color(0.85, 0.75, 0.2), "STAMINA")

	player.health.health_changed.connect(func(c, m): _health_fill.size.x = 300.0 * (c / m))
	player.stamina.stamina_changed.connect(func(c, m): _stamina_fill.size.x = 300.0 * (c / m))

	var help := Label.new()
	help.position = Vector2(40, 130)
	help.text = "A/D rör · Shift spring · Ctrl smyg · K garde\nJ light · U heavy · I spark · O roundhouse · L sweep"
	help.modulate = Color(1, 1, 1, 0.6)
	hud.add_child(help)

	_banner = Label.new()
	_banner.position = Vector2(760, 300)
	_banner.add_theme_font_size_override("font_size", 48)
	_banner.text = ""
	hud.add_child(_banner)

func _make_bar(hud: CanvasLayer, pos: Vector2, color: Color, label: String) -> ColorRect:
	var back := ColorRect.new()
	back.position = pos
	back.size = Vector2(300, 24)
	back.color = Color(0, 0, 0, 0.5)
	hud.add_child(back)

	var fill := ColorRect.new()
	fill.position = pos
	fill.size = Vector2(300, 24)
	fill.color = color
	hud.add_child(fill)

	var tag := Label.new()
	tag.position = pos + Vector2(310, 0)
	tag.text = label
	hud.add_child(tag)
	return fill

# --- Win / lose --------------------------------------------------------------
func _on_actor_died(actor: Node) -> void:
	if actor == player:
		_banner.text = "DU FÖLL"
		_banner.modulate = Color(0.9, 0.3, 0.3)
		return
	if actor is Enemy:
		_enemies_alive -= 1
		if _enemies_alive <= 0:
			_banner.text = "OMRÅDET SÄKRAT"
			_banner.modulate = Color(0.6, 0.9, 0.6)
