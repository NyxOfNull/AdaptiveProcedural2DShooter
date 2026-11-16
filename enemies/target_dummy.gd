extends StaticBody2D
## Test target: flashes when hit and vanishes when its Health reaches zero.

@onready var health: Health = $Health
@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.died.connect(queue_free)
	var dungeon := get_parent()
	if dungeon != null and dungeon.has_signal("dungeon_generated"):
		dungeon.dungeon_generated.connect(_on_dungeon_regenerated)


func _on_damaged(amount: float, _source: Node) -> void:
	sprite.modulate = Color(1.0, 0.35, 0.35)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	print("[Dummy] hit for %d, HP left %d" % [amount, health.current])


func _on_dungeon_regenerated(_ok: bool, _seed: int) -> void:
	queue_free()                            # old dummies vanish when a new dungeon is made
