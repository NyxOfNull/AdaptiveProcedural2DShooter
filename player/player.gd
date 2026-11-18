extends CharacterBody2D
## AP2DS - Player, step 1: 8-direction movement, 4-direction facing, sprite animation.
## Must be a direct child of the dungeon generator node (it spawns in the start room).

signal room_changed(room_id: int)   # -1 = not inside a room (corridor / doorway)

enum Facing { DOWN, UP, LEFT, RIGHT }

@export_group("Art")

## Tick if the SIDE row of your sheet shows the character looking LEFT. Untick if it looks mirrored.
@export var side_art_faces_left: bool = true

@export_group("Movement")
@export var max_speed: float = 110.0
@export var acceleration: float = 900.0
@export var friction: float = 1100.0
@export_range(0.0, 1.0) var attack_move_multiplier: float = 0.4   # slower while swinging

@export_group("Dash")
@export var dash_speed: float = 280.0
@export var dash_time: float = 0.14
@export var dash_cooldown: float = 0.6

@export_group("Body")
@export var body_radius: float = 5.0

@export_group("Weapons")
@export var starting_weapon: PackedScene
@export var test_dummy_scene: PackedScene     # temporary, for testing only

@onready var sprite: AnimatedSprite2D = $Sprite

@onready var health: Health = $Health
var dead := false

@onready var weapon_holder: Node2D = $WeaponHolder
var current_weapon: Weapon
var attacking := false

@onready var inventory: Inventory = get_node_or_null("Inventory")
var _equip_after_attack := false

var attack_held := false

var dungeon: Node
var has_dungeon := false
var facing: Facing = Facing.DOWN
var aim_dir: Vector2 = Vector2.DOWN      # toward the mouse (used by weapons later)
var current_room_id: int = -1

var _dash_left := 0.0
var _dash_cd := 0.0
var _dash_vec := Vector2.ZERO


func _ready() -> void:
	dungeon = get_parent()
	has_dungeon = dungeon != null and dungeon.has_signal("dungeon_generated")
	z_index = 1                                          # above tiles and start/exit markers
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING   # top-down movement
	collision_layer = 2                                  # the player lives on layer 2
	collision_mask =  1 | 4                                  # and collides with layer 1 (walls)
	_ensure_collision_shape()
	_ensure_input_actions()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_check_animations()
	_play_animation(false)

	if has_dungeon:
		dungeon.dungeon_generated.connect(_on_dungeon_generated)
		if dungeon.get_start_room_id() >= 0:
			spawn_at_start()

	if health == null:
		push_error("[Player] Add a child node named Health with health.gd attached.")
	else:
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
		health.health_changed.connect(_on_health_changed)
	if inventory != null:
		inventory.selected_changed.connect(_on_selection_changed)
		inventory.slot_changed.connect(_on_slot_changed)
		_equip_selected()
	else:
		equip_weapon(starting_weapon)       # fallback when there is no Inventory node


const REQUIRED_ANIMATIONS := ["idle_down", "idle_side", "idle_up", "walk_down", "walk_side", "walk_up", "death", "attack_sword_down", "attack_sword_side", "attack_sword_up"]

func _check_animations() -> void:
	if sprite.sprite_frames == null:
		push_error("[Player] Sprite has no SpriteFrames. Create them in the Inspector.")
		return
	for anim_name in REQUIRED_ANIMATIONS:
		if not sprite.sprite_frames.has_animation(anim_name):
			push_error("[Player] Missing animation: %s" % anim_name)


func _on_dungeon_generated(_success: bool, _used_seed: int) -> void:
	spawn_at_start()


func spawn_at_start() -> void:
	if not has_dungeon:
		return
	var start_id: int = dungeon.get_start_room_id()
	if start_id < 0:
		push_warning("[Player] The dungeon has no start room - nothing to spawn in.")
		return
	position = dungeon.get_room_center_world(start_id)
	velocity = Vector2.ZERO
	_dash_left = 0.0
	_dash_cd = 0.0
	facing = Facing.DOWN
	dead = false
	if health != null:
		health.reset()
	attacking = false
	current_room_id = -2          # forces room_changed to fire for the first room
	_update_current_room()


func _physics_process(delta: float) -> void:
	# Don't move while typing in the seed box.
	if dead:
		velocity = Vector2.ZERO
		return
	var typing := get_viewport().gui_get_focus_owner() != null
	var dir := Vector2.ZERO
	if not typing:
		# get_vector gives all 8 directions, and diagonals are already length 1 (no speed boost).
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		aim_dir = to_mouse.normalized()

	var speed := max_speed * (attack_move_multiplier if attacking else 1.0)
	_dash_cd = maxf(0.0, _dash_cd - delta)

	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = _dash_vec * dash_speed
	else:
		if not typing and Input.is_action_just_pressed("dash") and _dash_cd <= 0.0 and dir != Vector2.ZERO:
			_dash_vec = dir.normalized()
			if health != null:
				health.set_invulnerable(dash_time + 0.05)
			_dash_left = dash_time
			_dash_cd = dash_cooldown
			velocity = _dash_vec * dash_speed
		elif dir != Vector2.ZERO:
			velocity = velocity.move_toward(dir * speed, acceleration * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	if not attacking:
		if current_weapon != null and current_weapon.faces_cursor:
			_face_direction(_cardinal(aim_dir))      # guns: face the cursor, not the movement
		else:
			_update_facing(dir)
		_play_animation(velocity.length() > 10.0)

	# Hold-to-fire for automatic weapons.
	if attack_held and current_weapon != null and current_weapon.automatic:
		if Input.is_action_pressed("attack"):
			_try_attack()
		else:
			attack_held = false


# ---------------------------------------------------------------- facing / animation

# 8-direction input -> 4-direction facing.
func _update_facing(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return                                   # standing still: keep the last facing
	var ax := absf(dir.x)
	var ay := absf(dir.y)
	if ax > ay + 0.1:
		facing = Facing.RIGHT if dir.x > 0.0 else Facing.LEFT
	elif ay > ax + 0.1:
		facing = Facing.DOWN if dir.y > 0.0 else Facing.UP
	else:
		# Pure diagonal: keep facing along the current axis so it doesn't flicker.
		if facing == Facing.LEFT or facing == Facing.RIGHT:
			facing = Facing.RIGHT if dir.x > 0.0 else Facing.LEFT
		else:
			facing = Facing.DOWN if dir.y > 0.0 else Facing.UP


func _facing_suffix() -> String:
	match facing:
		Facing.DOWN:
			return "down"
		Facing.UP:
			return "up"
	return "side"


# One side row serves both left and right, so mirror it when needed.
func _apply_side_flip() -> void:
	sprite.flip_h = false
	if facing == Facing.LEFT:
		sprite.flip_h = not side_art_faces_left
	elif facing == Facing.RIGHT:
		sprite.flip_h = side_art_faces_left


func _play_animation(moving: bool) -> void:
	var anim := ("walk_" if moving else "idle_") + _facing_suffix()
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim):
		return
	if sprite.animation != anim:
		sprite.play(anim)
	_apply_side_flip()

# ---------------------------------------------------------------- room tracking / setup

func _update_current_room() -> void:
	if not has_dungeon:
		return
	var ts: int = dungeon.tile_size
	var tile := Vector2i(floori(position.x / ts), floori(position.y / ts))
	var found := -1
	for id in range(dungeon.rooms.size()):
		if dungeon.get_room_rect_tiles(id).has_point(tile):
			found = id
			break
	if found != current_room_id:
		current_room_id = found
		room_changed.emit(found)


func _ensure_collision_shape() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			return
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)


# Creates the input actions in code. Existing actions with these names are left alone.
func _ensure_input_actions() -> void:
	_add_action_if_missing("move_left", [KEY_A, KEY_LEFT])
	_add_action_if_missing("move_right", [KEY_D, KEY_RIGHT])
	_add_action_if_missing("move_up", [KEY_W, KEY_UP])
	_add_action_if_missing("move_down", [KEY_S, KEY_DOWN])
	_add_action_if_missing("dash", [KEY_SPACE])
	
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", click)


func _add_action_if_missing(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


# ---------------------------------------------------------------- health reactions

func _on_damaged(_amount: float, _source: Node) -> void:
	# Flash red, then fade back to normal.
	sprite.modulate = Color(1.0, 0.35, 0.35)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)


func _on_died() -> void:
	dead = true
	sprite.flip_h = false
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")


func _on_health_changed(current: float, maximum: float) -> void:
	print("[Player] HP %d / %d" % [int(current), int(maximum)])


# TEMPORARY debug keys for testing: K = take 10 damage, J = heal 10. Remove later.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		attack_held = true
		_try_attack()
		return
	if event.is_action_released("attack"):
		attack_held = false
		return

	# Mouse wheel cycles through the hotbar.
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and inventory != null:
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			inventory.cycle(-1)
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			inventory.cycle(1)
		return

	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	# Number keys 1-9 pick a hotbar slot.
	var number := int(key.keycode) - int(KEY_1)
	if inventory != null and number >= 0 and number < mini(9, inventory.hotbar_size):
		inventory.select(number)
		return

	# TEMPORARY debug keys: K = take damage, J = heal, T = spawn a target dummy,
	# X = remove the selected item, Z = give the first starting item back.
	if key.keycode == KEY_K and health != null:
		health.take_damage(10.0, self)
	elif key.keycode == KEY_J and health != null:
		health.heal(10.0)
	elif key.keycode == KEY_T and test_dummy_scene != null and has_dungeon:
		var dummy := test_dummy_scene.instantiate()
		dummy.position = position + _cardinal(aim_dir) * 48.0
		dungeon.add_child(dummy)
	elif key.keycode == KEY_X and inventory != null:
		inventory.remove_item(inventory.selected)
	elif key.keycode == KEY_Z and inventory != null and not inventory.starting_items.is_empty():
		inventory.add_item(inventory.starting_items[0])


# ---------------------------------------------------------------- weapons

func equip_weapon(scene: PackedScene) -> void:
	if current_weapon != null:
		current_weapon.queue_free()
		current_weapon = null
	if scene == null:
		return
	var weapon := scene.instantiate() as Weapon
	if weapon == null:
		push_error("[Player] That scene's root does not extend Weapon.")
		return
	weapon_holder.add_child(weapon)
	weapon.owner_player = self
	current_weapon = weapon


func _face_direction(dir: Vector2) -> void:
	if dir.x > 0.0:
		facing = Facing.RIGHT
	elif dir.x < 0.0:
		facing = Facing.LEFT
	elif dir.y > 0.0:
		facing = Facing.DOWN
	else:
		facing = Facing.UP


func _try_attack() -> void:
	if dead or attacking or current_weapon == null:
		return
	var dir := _cardinal(aim_dir)
	if not current_weapon.try_attack(dir, aim_dir):   # false while on cooldown
		return
	_face_direction(dir)
	if current_weapon.animation_name == "":
		return                                        # no attack animation (guns): keep moving freely

	attacking = true
	var anim := "attack_%s_%s" % [current_weapon.animation_name, _facing_suffix()]
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
		_apply_side_flip()
	await get_tree().create_timer(current_weapon.attack_duration).timeout
	attacking = false
	if _equip_after_attack:
		_equip_after_attack = false
		_equip_selected()


# Turns any direction into the nearest of up / down / left / right.
func _cardinal(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2(signf(v.x), 0.0)
	return Vector2(0.0, signf(v.y))



# ---------------------------------------------------------------- inventory

func _on_selection_changed(_index: int) -> void:
	_equip_selected()


func _on_slot_changed(index: int) -> void:
	if index == inventory.selected:
		_equip_selected()


# Equips the item in the selected slot (an empty slot means unarmed).
func _equip_selected() -> void:
	if attacking:
		_equip_after_attack = true          # never swap a weapon in the middle of a swing
		return
	var item := inventory.get_selected_item()
	equip_weapon(item.weapon_scene if item != null else null)
