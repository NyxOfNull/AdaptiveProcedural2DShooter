class_name Weapon
extends Node2D
## Base class for every weapon. A weapon is its own scene, placed under the player's WeaponHolder.

signal attack_started

@export var weapon_name: String = "Weapon"
@export var icon: Texture2D                 # used by the inventory later
@export var damage: float = 10.0
@export var cooldown: float = 0.4           # seconds between attacks
## The player plays attack_<animation_name>_down / _side / _up. Leave EMPTY for no attack animation.
@export var animation_name: String = "sword"
## How long the player stays locked in the attack animation.
@export var attack_duration: float = 0.35

@export_group("Aiming")
## The player faces the mouse cursor while this weapon is equipped.
@export var faces_cursor: bool = false
## Hold the attack button to keep firing.
@export var automatic: bool = false

var owner_player: Node                      # set by the player when equipped
var aim_vector: Vector2 = Vector2.RIGHT     # exact direction to the cursor (360 degrees)
var _cooldown_left: float = 0.0


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta


func can_attack() -> bool:
	return _cooldown_left <= 0.0


## direction = nearest of the 4 cardinal vectors, aim = exact direction to the cursor.
## Returns true if the attack really started.
func try_attack(direction: Vector2, aim: Vector2 = Vector2.ZERO) -> bool:
	if not can_attack():
		return false
	_cooldown_left = cooldown
	aim_vector = aim.normalized() if aim != Vector2.ZERO else direction
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
