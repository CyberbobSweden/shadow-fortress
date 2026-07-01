extends Node
## Registered as the autoload "Encounter".
##
## Limits how many enemies may *commit* to an attack at the same time. This is
## what makes a 3-on-1 fight read as deliberate ("they wait, then strike
## together") instead of a swarm that mobs you instantly. Enemies must hold a
## token to attack; everyone else circles, blocks, or repositions.
##
## Two attackers at once is the sweet spot for a Karateka-style timing game:
## enough pressure to be scary, few enough that a skilled player can read it.

@export var max_simultaneous_attackers: int = 2

var _tokens_in_use: int = 0

func request_token() -> bool:
	if _tokens_in_use < max_simultaneous_attackers:
		_tokens_in_use += 1
		return true
	return false

func release_token() -> void:
	_tokens_in_use = maxi(_tokens_in_use - 1, 0)

func reset() -> void:
	_tokens_in_use = 0
