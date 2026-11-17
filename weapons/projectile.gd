class_name Projectile
extends Area2D
## A bullet. Flies straight, damages the first thing with a Health node, vanishes on any hit.
## Collision: Layer = none, Mask = what it can hit (walls = 1, enemies = 3).

@export var speed: float = 320.0
@export var lifetime: float = 1.2           # seconds before it disappears on its own

var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var shooter: Node
var _life_left: float = 0.0
var _done := false


func _ready() -> void:
	_life_left = lifetime
	body_entered.connect(_on_body_entered)


func launch(from: Vector2, dir: Vector2, dmg: float, who: Node) -> void:
	global_position = from
	direction = dir.normalized()
	rotation = direction.angle()
	damage = dmg
	shooter = who


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _done or body == shooter:
		return
	_done = true
	for child in body.get_children():
		if child is Health:
			child.take_damage(damage, shooter)
			break
	queue_free()                            # walls and enemies both stop the bullet
