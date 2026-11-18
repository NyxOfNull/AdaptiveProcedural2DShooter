extends CanvasLayer
## AP2DS - Inventory screen. Tab or I opens it. Click an item to pick it up, click another slot to swap.

@export var inventory: Inventory
@export var backpack_columns: int = 5
@export var slot_size: Vector2 = Vector2(52, 52)
@export var normal_color: Color = Color(0.35, 0.35, 0.4)
@export var hotbar_color: Color = Color(0.12, 0.64, 0.6)     # the selected hotbar slot
@export var picked_color: Color = Color(0.88, 0.48, 0.37)    # the slot you picked up

var _panels: Array[PanelContainer] = []
var _icons: Array[TextureRect] = []
var _info: Label
var _picked: int = -1
var _hover: int = -1


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS      # keep working while the game is paused
	visible = false
	_ensure_action("inventory", [KEY_TAB, KEY_I])
	if inventory == null:
		push_error("[InventoryScreen] Assign the Inventory node in the Inspector.")
		return
	_build()
	inventory.slot_changed.connect(_on_inventory_changed)
	inventory.selected_changed.connect(_on_inventory_changed)


func _exit_tree() -> void:
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if inventory == null:
		return
	if event.is_action_pressed("inventory"):
		_set_open(not visible)
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	visible = open
	get_tree().paused = open                      # game stops while the screen is open
	_picked = -1
	_hover = -1
	if open:
		_refresh()


func _on_inventory_changed(_index: int) -> void:
	if visible:
		_refresh()


# ---------------------------------------------------------------- building the UI

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var window := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.13, 0.18, 0.96)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	window.add_theme_stylebox_override("panel", style)
	center.add_child(window)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	window.add_child(box)

	box.add_child(_make_label("Inventory", 20))
	box.add_child(_make_label("Hotbar (keys 1-%d)" % inventory.hotbar_size, 13))
	var hotbar_grid := GridContainer.new()
	hotbar_grid.columns = inventory.hotbar_size
	box.add_child(hotbar_grid)

	box.add_child(_make_label("Backpack", 13))
	var pack_grid := GridContainer.new()
	pack_grid.columns = backpack_columns
	box.add_child(pack_grid)

	for i in range(inventory.slot_count):
		var slot := _make_slot(i)
		(hotbar_grid if i < inventory.hotbar_size else pack_grid).add_child(slot)

	_info = _make_label("", 13)
	_info.custom_minimum_size = Vector2(0, 40)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)
	box.add_child(_make_label("Click an item, then another slot, to move or swap.   Tab / I / Esc closes.", 11))


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_slot(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = slot_size
	panel.focus_mode = Control.FOCUS_NONE
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	panel.gui_input.connect(_on_slot_input.bind(index))
	panel.mouse_entered.connect(_on_hover.bind(index))
	panel.mouse_exited.connect(_on_hover.bind(-1))
	_panels.append(panel)
	_icons.append(icon)
	return panel


# ---------------------------------------------------------------- interaction

func _on_hover(index: int) -> void:
	_hover = index
	_refresh()


func _on_slot_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if _picked == -1:
		if inventory.slots[index] != null:
			_picked = index                       # pick up
	elif _picked == index:
		_picked = -1                              # click the same slot again to cancel
	else:
		inventory.swap_slots(_picked, index)      # move or swap
		_picked = -1
	_refresh()


func _refresh() -> void:
	for i in range(_panels.size()):
		var item := inventory.slots[i]
		_icons[i].texture = item.icon if item != null else null
		var border := normal_color
		var width := 2
		if i == inventory.selected:
			border = hotbar_color
			width = 3
		if i == _picked:
			border = picked_color
			width = 4
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.55)
		style.border_color = border
		style.set_border_width_all(width)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(4)
		_panels[i].add_theme_stylebox_override("panel", style)

	var shown := _hover if _hover >= 0 else _picked
	var shown_item: ItemData = inventory.slots[shown] if shown >= 0 else null
	if shown_item != null:
		_info.text = "%s\n%s" % [shown_item.item_name, shown_item.description]
	else:
		_info.text = ""


func _ensure_action(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
