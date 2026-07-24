class_name TileType
extends Resource

enum Category { SOURCE, BELT, TRANSFORM, SPLITTER, SINK }

@export var display_name: String
@export var category: Category = Category.BELT

@export_group("Art")
@export var source_id: int
@export var atlas_coords: Vector2i = Vector2i(0, 0)

@export_group("Connectors")
@export_flags("Right:1", "Down:2", "Left:4", "Up:8") var inputs: int = 0
@export_flags("Right:1", "Down:2", "Left:4", "Up:8") var outputs: int = 0

@export_group("Behaviour")
@export var amount: float = 0.0
