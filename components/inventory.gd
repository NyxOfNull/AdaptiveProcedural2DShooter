class_name Inventory
extends Node
## Holds a fixed number of item slots and which one is selected. Pure data; the UI listens to signals.

signal slot_changed(index: int)
signal selected_changed(index: int)

@export var slot_count: int = 5
@export var starting_items: Array[ItemData] = []

var slots: Array[ItemData] = []      # null = empty slot
var selected: int = 0


func _ready() -> void:
	slots.resize(maxi(1, slot_count))
	for i in range(mini(starting_items.size(), slots.size())):
		slots[i] = starting_items[i]


func get_selected_item() -> ItemData:
	return slots[selected] if selected < slots.size() else null


func select(index: int) -> void:
	if index < 0 or index >= slots.size() or index == selected:
		return
	selected = index
	selected_changed.emit(index)


## step = +1 next slot, -1 previous slot (wraps around).
func cycle(step: int) -> void:
	select(posmod(selected + step, slots.size()))


## Puts the item in the first empty slot. Returns false if the hotbar is full.
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
