extends CanvasLayer
## AP2DS - Hotbar: one box per inventory slot, with the selected slot highlighted.

@export var inventory: Inventory
@export var slot_size: Vector2 = Vector2(44, 44)
@export var normal_color: Color = Color(0.35, 0.35, 0.4)
@export var selected_color: Color = Color(0.12, 0.64, 0.6)

var _panels: Array[PanelContainer] = []
var _icons: Array[TextureRect] = []


func _ready() -> void:
	layer = 5
	if inventory == null:
		push_error("[Hotbar] Assign the Inventory node in the Inspector.")
		return
	_build()
	inventory.slot_changed.connect(_on_inventory_changed)
	inventory.selected_changed.connect(_on_inventory_changed)
	_refresh.call_deferred()              # wait until the inventory has filled its slots


func _on_inventory_changed(_index: int) -> void:
	_refresh()


func _build() -> void:
	var holder := VBoxContainer.new()     # full screen, content pushed to the bottom
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 6)
	holder.add_child(row)

	var gap := Control.new()              # margin under the hotbar
	gap.custom_minimum_size = Vector2(0, 12)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(gap)

	for i in range(inventory.hotbar_size):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = slot_size
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		var number := Label.new()
		number.text = str(i + 1)
		number.add_theme_font_size_override("font_size", 11)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(number)
		row.add_child(panel)
		_panels.append(panel)
		_icons.append(icon)


func _refresh() -> void:
	for i in range(_panels.size()):
		var item := inventory.slots[i]
		_icons[i].texture = item.icon if item != null else null
		_panels[i].tooltip_text = item.item_name if item != null else "Empty"
		var is_selected := i == inventory.selected
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.6)
		style.border_color = selected_color if is_selected else normal_color
		style.set_border_width_all(3 if is_selected else 2)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(4)
		_panels[i].add_theme_stylebox_override("panel", style)
