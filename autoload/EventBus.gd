extends Node
## Global signal hub (registered as the autoload "EventBus").
##
## Every system that needs to talk across module boundaries does it through
## here, so the HUD, audio, and gameplay never hold direct references to each
## other. Emit from gameplay, listen from UI/audio. Nothing else.

# --- Combat ------------------------------------------------------------------
signal actor_damaged(actor: Node, amount: float, source: Node)
signal actor_died(actor: Node)
signal attack_landed(attacker: Node, target: Node, attack: AttackData)
signal attack_blocked(attacker: Node, target: Node, attack: AttackData)
signal attack_perfect_blocked(defender: Node, attacker: Node)
signal attack_parried(defender: Node, attacker: Node)
signal guard_broken(actor: Node)
signal knockdown(actor: Node)

# --- HUD / framing -----------------------------------------------------------
signal player_health_changed(current: float, maximum: float)
signal player_stamina_changed(current: float, maximum: float)
signal boss_encountered(boss: Node, display_name: String, max_health: float)
signal boss_health_changed(current: float, maximum: float)
signal boss_defeated(boss: Node)
signal camera_shake_requested(strength: float, duration: float)

# --- Stealth / world ---------------------------------------------------------
signal noise_emitted(position: Vector2, radius: float, source: Node)
signal player_spotted(by: Node)
signal alarm_raised(position: Vector2)
signal checkpoint_reached(id: StringName)
