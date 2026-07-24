@tool
class_name TileType
extends Resource

enum Placement { BASE, MODIFIER }
enum Category { SOURCE = 0, BELT = 1, SINK = 2, ADDER = 3, MULTIPLIER = 4, UPGRADER = 5, DOWNGRADER = 6, SPLITTER = 7 }

@export var display_name: String
@export var placement: Placement = Placement.BASE:
	set(value):
		placement = value
		notify_property_list_changed()

func _validate_property(property: Dictionary) -> void:
	if property.name == "category":
		property.hint = PROPERTY_HINT_ENUM
		if placement == Placement.MODIFIER:
			property.hint_string = "Adder:3,Multiplier:4,Upgrader:5,Downgrader:6,Splitter:7"
		else:
			property.hint_string = "Source:0,Belt:1,Sink:2"
	elif property.name in ["inputs", "outputs"]:
		if placement == Placement.MODIFIER:
			property.usage = PROPERTY_USAGE_NONE

@export var category: Category = Category.BELT

@export_group("Art")
@export var source_id: int
@export var atlas_coords: Vector2i = Vector2i(0, 0)

@export_group("Connectors")
@export_flags("Right:1", "Down:2", "Left:4", "Up:8") var inputs: int = 0
@export_flags("Right:1", "Down:2", "Left:4", "Up:8") var outputs: int = 0

@export_group("Behaviour")
@export var emits: ItemType
@export var amount: float = 0.0
