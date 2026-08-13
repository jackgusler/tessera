class_name ItemType
extends Resource

@export var display_name: String
@export var tier_textures: Array[Texture2D]
@export var tier_values: Array[float]

func max_tier() -> int:
	return tier_textures.size() - 1
