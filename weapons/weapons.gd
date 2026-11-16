class_name Weapon
extends Node2D
## Base class for every weapon. A weapon is its own scene, placed under the player's WeaponHolder.

signal attack_started

@export var weapon_name: String = "Weapon"
@export var icon: Texture2D                 # used by the inventory later
@export var damage: float = 10.0
@export var cooldown: float = 0.4           # seconds between attacks
## The player plays attack_<animation_name>_down / _side / _up.
@export var animation_name: String = "sword"
## How long the player stays locked in the attack animation.
@export var attack_duration: float = 0.35

var owner_player: Node                      # set by the player when equipped
var _cooldown_left: float = 0.0


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta


func can_attack() -> bool:
	return _cooldown_left <= 0.0


## Called by the player. direction = one of the 4 cardinal unit vectors.
## Returns true if the attack really started.
func try_attack(direction: Vector2) -> bool:
	if not can_attack():
		return false
	_cooldown_left = cooldown
	attack_started.emit()
	_perform_attack(direction)
	return true


func _perform_attack(_direction: Vector2) -> void:
	pass                                    # each weapon type overrides this


func _find_health(node: Node) -> Health:
	for child in node.get_children():
		if child is Health:
			return child
	return null
