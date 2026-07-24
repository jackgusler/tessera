class_name gridContainer
extends Node2D

@onready var grid_layer: TileMapLayer = $Grid
@onready var placeable: TileMapLayer = $Placeable
@onready var preview: TileMapLayer = $Preview

@export var grid_width: int = 6
@export var grid_height: int = 6
@export var cell_size: int = 16
@export var tile_types: Array[TileType]
var current_type_index: int = 0
var current_rotation: int = 0   # 0..3


const GRID_ORIGIN := Vector2i(-3, -3)
const ORTHO: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var grid: Array
var modifiers: Array

func _process(_delta: float) -> void:
	_update_ghost()

func _ready() -> void:
	_build_grid()

func _build_grid() -> void:
	grid = []
	for y in grid_height:
		var row = []
		for x in grid_width:
			row.append(null)
		grid.append(row)
		
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		current_rotation = (current_rotation + 1) % 4

func _handle_left_click() -> void:
	var local := placeable.get_local_mouse_position()
	var map_cell := placeable.local_to_map(local)
	var cell := map_to_board(map_cell)
	if not is_in_bounds(cell):
		return
	if not is_empty(cell):
		return
	var t := Tile.new()
	t.type = current_type()
	t.rotation = current_rotation
	place_tile(cell, t)

func _handle_right_click() -> void:
	var local := placeable.get_local_mouse_position()
	var map_cell := placeable.local_to_map(local)
	var cell := map_to_board(map_cell)
	if not is_in_bounds(cell):
		return
	if is_empty(cell):
		return
	remove_tile(cell)
	
func _update_ghost() -> void:
	preview.clear()
	var cell := _cell_under_mouse()
	if not is_in_bounds(cell):
		return
	if not is_empty(cell):
		return
	var type := current_type()
	preview.set_cell(board_to_map(cell), type.source_id, type.atlas_coords, _rotation_to_alt(current_rotation))

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
	placeable.set_cell(board_to_map(cell), tile.type.source_id, tile.type.atlas_coords, _rotation_to_alt(tile.rotation))

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
	
func _rotation_to_alt(rot: int) -> int:
	match rot:
		1: return TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
		2: return TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
		3: return TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V
		_: return 0
		
func current_type() -> TileType:
	return tile_types[current_type_index]

func _cell_under_mouse() -> Vector2i:
	return map_to_board(placeable.local_to_map(placeable.get_local_mouse_position()))

func board_to_map(cell: Vector2i) -> Vector2i:
	return cell + GRID_ORIGIN

func map_to_board(map_cell: Vector2i) -> Vector2i:
	return map_cell - GRID_ORIGIN
