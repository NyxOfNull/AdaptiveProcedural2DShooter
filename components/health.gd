class_name Health
extends Node
## AP2DS - Reusable health component. Add it as a child of anything that can be hurt
## (player, enemies, breakable props). Other nodes react through its signals.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal died

@export var max_health: float = 100.0
## After a hit, ignore further damage for this many seconds (0 = off).
@export var invulnerability_time: float = 0.5

var current: float = 0.0
var is_dead: bool = false
var _invuln_left: float = 0.0


func _ready() -> void:
	current = max_health


func _process(delta: float) -> void:
	if _invuln_left > 0.0:
		_invuln_left -= delta


func is_invulnerable() -> bool:
	return _invuln_left > 0.0


## Ignore all damage for a while (the dash uses this).
func set_invulnerable(seconds: float) -> void:
	_invuln_left = maxf(_invuln_left, seconds)


## Returns true if the hit actually landed.
func take_damage(amount: float, source: Node = null) -> bool:
	if is_dead or amount <= 0.0 or is_invulnerable():
		return false
	current = maxf(0.0, current - amount)
	damaged.emit(amount, source)
	health_changed.emit(current, max_health)
	if current <= 0.0:
		is_dead = true
		died.emit()
	else:
		_invuln_left = invulnerability_time
	return true


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	var before := current
	current = minf(max_health, current + amount)
	if current > before:
		healed.emit(current - before)
		health_changed.emit(current, max_health)


## Full health again (used when respawning).
func reset() -> void:
	current = max_health
	is_dead = false
	_invuln_left = 0.0
	health_changed.emit(current, max_health)
