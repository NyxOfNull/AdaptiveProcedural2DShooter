class_name ItemData
extends Resource
## One kind of item. Create instances as .tres files (FileSystem > right-click > Create New > Resource).

@export var item_name: String = "Item"
@export_multiline var description: String = ""
@export var icon: Texture2D
## For weapons: the scene that is placed under the player's WeaponHolder.
@export var weapon_scene: PackedScene
