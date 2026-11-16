class_name MeleeWeapon
extends Weapon
## Close-range weapon: an Area2D "Hitbox" switches on briefly in front of the player.

@export var hit_delay: float = 0.08         # wind-up before the hitbox turns on
@export var hit_duration: float = 0.12      # how long the hitbox stays on
@export var reach: float = 16.0             # distance of the hitbox centre from the player
@export var hit_origin: Vector2 = Vector2(0, -6)   # roughly body height (player origin is at the feet)

@onready var hitbox: Area2D = get_node_or_null("Hitbox")

var _already_hit: Array[Node] = []


func _ready() -> void:
	if hitbox == null:
		push_error("[Weapon] %s needs a child Area2D named exactly 'Hitbox'." % name)
		return
	hitbox.monitoring = false


func _perform_attack(direction: Vector2) -> void:
	hitbox.position = hit_origin + direction * reach
	hitbox.rotation = direction.angle()
	_already_hit.clear()                    # each target can be hit once per swing

	await get_tree().create_timer(hit_delay).timeout
	if not is_inside_tree():
		return
	hitbox.monitoring = true

	var elapsed := 0.0
	while elapsed < hit_duration:
		_apply_hits()
		await get_tree().physics_frame
		if not is_inside_tree():
			return
		elapsed += get_physics_process_delta_time()
	hitbox.monitoring = false


func _apply_hits() -> void:
	for body in hitbox.get_overlapping_bodies():
		if body in _already_hit:
			continue
		var health := _find_health(body)
		if health != null:
			_already_hit.append(body)
			health.take_damage(damage, owner_player)
