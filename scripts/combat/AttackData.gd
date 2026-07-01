class_name AttackData
extends Resource
## Data-driven attack definition. Each attack is a .tres resource so designers
## tune frame data and damage in the inspector without touching code. Frame
## counts are authored at 60 FPS and converted to seconds at runtime, so the
## numbers match what an animator counts on a sprite sheet.

enum Height { HIGH, MID, LOW }

@export var id: StringName = &"light_punch"
@export var display_name: String = "Light Punch"
## Defenders must block at the matching height. LOW (sweeps) must be blocked low.
@export var height: Height = Height.MID

@export_group("Frames @ 60 FPS")
@export var startup_frames: int = 6   ## wind-up before the hit is live
@export var active_frames: int = 3    ## frames the hitbox can connect
@export var recovery_frames: int = 10 ## lockout after — this is the punish window

@export_group("Effect")
@export var damage: float = 6.0
@export var chip_damage: float = 1.0       ## damage that leaks through a block
@export var balance_damage: float = 4.0    ## poise removed from the target
@export var stamina_cost: float = 8.0
@export var knockback: float = 40.0
@export var reach: float = 1.1             ## metres; AI uses this for spacing

@export_group("Defence interaction")
@export var unblockable: bool = false
@export var beats_block: bool = false   ## throws set this true

func startup_time() -> float:
	return startup_frames / 60.0

func active_time() -> float:
	return active_frames / 60.0

func recovery_time() -> float:
	return recovery_frames / 60.0

func total_time() -> float:
	return (startup_frames + active_frames + recovery_frames) / 60.0
