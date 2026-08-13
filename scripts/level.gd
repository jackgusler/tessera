class_name Level
extends Resource

@export var display_name: String
@export var target: float = 0.0
@export var grid_width: int = 6
@export var grid_height: int = 6
@export var conveyors: int = 0
@export var fixed_tiles: Array[PlacedTile]   # generator + sink, pre-placed and unremovable
@export var inventory: Array[InventorySlot]  # what the player gets to work with
