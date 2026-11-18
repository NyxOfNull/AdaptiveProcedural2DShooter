class_name Inventory
extends Node
## Holds item slots and which hotbar slot is selected. Pure data; UIs listen to the signals.
## The first hotbar_size slots are the hotbar, the remaining slots are the backpack.

signal slot_changed(index: int)
signal selected_changed(index: int)

@export var slot_count: int = 15
@export var hotbar_size: int = 5
@export var starting_items: Array[ItemData] = []   # empty entries are allowed (they leave a gap)

var slots: Array[ItemData] = []      # null = empty slot
var selected: int = 0                # always inside the hotbar


func _ready() -> void:
	slot_count = maxi(1, slot_count)
	hotbar_size = clampi(hotbar_size, 1, slot_count)
	slots.resize(slot_count)
	for i in range(mini(starting_items.size(), slots.size())):
		slots[i] = starting_items[i]


func get_selected_item() -> ItemData:
	return slots[selected] if selected < slots.size() else null


## Only hotbar slots can be selected.
func select(index: int) -> void:
	if index < 0 or index >= hotbar_size or index == selected:
		return
	selected = index
	selected_changed.emit(index)


## step = +1 next slot, -1 previous slot (wraps around inside the hotbar).
func cycle(step: int) -> void:
	select(posmod(selected + step, hotbar_size))


## Puts the item in the first empty slot (hotbar first, then backpack). False if everything is full.
func add_item(item: ItemData) -> bool:
	for i in range(slots.size()):
		if slots[i] == null:
			slots[i] = item
			slot_changed.emit(i)
			return true
	return false


func remove_item(index: int) -> ItemData:
	if index < 0 or index >= slots.size():
		return null
	var removed := slots[index]
	slots[index] = null
	slot_changed.emit(index)
	return removed


## Swaps two slots. If one is empty, the item simply moves.
func swap_slots(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= slots.size() or b >= slots.size():
		return
	var temp := slots[a]
	slots[a] = slots[b]
	slots[b] = temp
	slot_changed.emit(a)
	slot_changed.emit(b)
