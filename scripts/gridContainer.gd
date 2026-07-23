class_name gridContainer
extends Node2D

@onready var placeable: TileMapLayer = $Placeable
@onready var grid_layer: TileMapLayer = $Grid

@export var grid_width: int = 6
@export var grid_height: int = 6
@export var cell_size: int = 16

const GRID_ORIGIN := Vector2i(-3, -3)
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

func get_tile(cell: Vector2i) -> Tile:
	assert(is_in_bounds(cell), "get_tile out of bounds: %s" % cell)
	return grid[cell.y][cell.x]

func is_empty(cell: Vector2i) -> bool:
	return get_tile(cell) == null
	
func place_tile(cell: Vector2i, tile: Tile) -> void:
	assert(is_in_bounds(cell), "place_tile out of bounds: %s" % cell)
	assert(is_empty(cell), "place_tile on occupied cell: %s" % cell)
	grid[cell.y][cell.x] = tile
	placeable.set_cell(board_to_map(cell), tile.source_id, tile.atlas_coords )

func remove_tile(cell: Vector2i) -> void:
	assert(is_in_bounds(cell), "remove_tile out of bounds: %s" % cell)
	grid[cell.y][cell.x] = null
	placeable.erase_cell(board_to_map(cell))
	
func clear() -> void:
	_build_grid()
	placeable.clear()
	
func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in ORTHO:
		var n: Vector2i = cell + d
		if is_in_bounds(n):
			out.append(n)
	return out
	
func board_to_map(cell: Vector2i) -> Vector2i:
	return cell + GRID_ORIGIN

func map_to_board(map_cell: Vector2i) -> Vector2i:
	return map_cell - GRID_ORIGIN
