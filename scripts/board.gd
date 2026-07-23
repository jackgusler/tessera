class_name Board
extends Node2D

@export var grid_width: int = 6
@export var grid_height: int = 6
@export var cell_size: int = 16

const ORTHO: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var grid: Array

func _ready() -> void:
	_build_grid()

func _build_grid() -> void:
	grid = []
	for y in grid_height:
		var row = []
		for x in grid_width:
			row.append(null)
		grid.append(row)

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_width and cell.y < grid_height

func get_tile(cell: Vector2i) -> Variant:
	assert(is_in_bounds(cell), "get_tile out of bounds: %s" % cell)
	return grid[cell.y][cell.x]

func is_empty(cell: Vector2i) -> bool:
	return get_tile(cell) == null
	
func place_tile(cell: Vector2i, tile: Variant) -> void:
	assert(is_in_bounds(cell), "place_tile out of bounds: %s" % cell)
	assert(is_empty(cell))
	grid[cell.y][cell.x] = tile

func remove_tile(cell: Vector2i) -> void:
	place_tile(cell, null)
	
func clear() -> void:
	_build_grid()
	
func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in ORTHO:
		var n: Vector2i = cell + d
		if is_in_bounds(n):
			out.append(n)
	return out
