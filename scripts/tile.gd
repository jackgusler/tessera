class_name Tile
extends RefCounted

var type: TileType
var rotation: int = 0
var current_value: float = 0.0

func rotated_inputs() -> int:
	return _rotate_mask(type.inputs, rotation)
	
func rotated_outputs() -> int:
	return _rotate_mask(type.outputs, rotation)
	
static func _rotate_mask(mask: int, steps: int) -> int:
	var m := mask
	for _i in steps:
		m = ((m << 1) | (m >> 3)) & 0b1111
	return m
