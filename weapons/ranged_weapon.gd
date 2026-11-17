class_name RangedWeapon
extends Weapon
## Fires projectiles toward the cursor. Pellets and spread turn a pistol into a shotgun.

@export var projectile_scene: PackedScene
@export var projectile_count: int = 1
@export var spread_degrees: float = 3.0
@export var hold_origin: Vector2 = Vector2(0, -6)   # where the gun is held (player origin = feet)
@export var hold_distance: float = 8.0

@onready var muzzle: Marker2D = get_node_or_null("Muzzle")


func _process(delta: float) -> void:
	super(delta)                                     # keeps the cooldown running
	if owner_player == null:
		return
	var aim: Vector2 = owner_player.aim_dir
	position = hold_origin + aim * hold_distance
	rotation = aim.angle()
	scale.y = -1.0 if aim.x < 0.0 else 1.0           # keep the gun upright when aiming left


func _perform_attack(_direction: Vector2) -> void:
	if projectile_scene == null:
		push_error("[Weapon] %s has no Projectile Scene assigned." % weapon_name)
		return
	var origin := muzzle.global_position if muzzle != null else global_position
	var parent := owner_player.get_parent()          # bullets live in the dungeon, not on the player
	var base_angle := aim_vector.angle()
	for i in range(maxi(1, projectile_count)):
		var angle := base_angle + deg_to_rad(randf_range(-spread_degrees, spread_degrees))
		var bullet := projectile_scene.instantiate() as Projectile
		if bullet == null:
			push_error("[Weapon] The projectile scene's root must use projectile.gd.")
			return
		parent.add_child(bullet)
		bullet.launch(origin, Vector2.RIGHT.rotated(angle), damage, owner_player)
