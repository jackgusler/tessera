class_name gridContainer
extends Node2D

@onready var grid_layer: TileMapLayer = $Grid
@onready var base_layer: TileMapLayer = $Base
@onready var items_layer: TileMapLayer = $Items
@onready var modifiers_layer: TileMapLayer = $Modifiers
@onready var preview: TileMapLayer = $Preview

@export var database: TileDatabase
@export var grid_width: int = 6
@export var grid_height: int = 6
@export var cell_size: int = 16

var _source_by_texture: Dictionary = {}

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
	_build_source_lookup()

func _build_grid() -> void:
	grid = _empty_board()
	modifiers = _empty_board()
	
func _empty_board() -> Array:
	var board := []
	for y in grid_height:
		var row := []
		row.resize(grid_width)
		board.append(row)
	return board

func _board_for(placement: int) -> Array:
	return modifiers if placement == TileType.Placement.MODIFIER else grid

func _build_source_lookup() -> void:
	_source_by_texture.clear()
	for layer in [base_layer, items_layer, modifiers_layer]:
		_source_by_texture[layer.tile_set] = _sources_for(layer.tile_set)

func _sources_for(ts: TileSet) -> Dictionary:
	var out := {}
	for i in ts.get_source_count():
		var id := ts.get_source_id(i)
		var src := ts.get_source(id) as TileSetAtlasSource
		if src and src.texture:
			out[src.texture] = id
	return out

func _source_id(layer: TileMapLayer, texture: Texture2D) -> int:
	var lookup: Dictionary = _source_by_texture.get(layer.tile_set, {})
	return lookup.get(texture, -1)

func layer_for(type: TileType) -> TileMapLayer:
	match type.placement:
		TileType.Placement.MODIFIER: return modifiers_layer
		_: return base_layer

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		current_rotation = (current_rotation + 1) % 4

func can_place(cell: Vector2i, type: TileType) -> bool:
	if not is_in_bounds(cell):
		return false
	if not is_empty(cell, type.placement):
		return false
	if type.placement == TileType.Placement.MODIFIER:
		return not is_empty(cell, TileType.Placement.BASE)
	return true

func _handle_left_click() -> void:
	var cell := _cell_under_mouse()
	var type := current_type()
	if not can_place(cell, type):
		return
	var t := Tile.new()
	t.type = type
	t.rotation = current_rotation
	place_tile(cell, t)

func _handle_right_click() -> void:
	var cell := _cell_under_mouse()
	if not is_in_bounds(cell):
		return
	if not is_empty(cell, TileType.Placement.MODIFIER):
		remove_tile(cell, TileType.Placement.MODIFIER)
	elif not is_empty(cell, TileType.Placement.BASE):
		remove_tile(cell, TileType.Placement.BASE)
	
func _update_ghost() -> void:
	preview.clear()
	var cell := _cell_under_mouse()
	var type := current_type()
	if not can_place(cell, type):
		return
	var layer := layer_for(type)
	if preview.tile_set != layer.tile_set:
		preview.tile_set = layer.tile_set
	preview.set_cell(board_to_map(cell), _source_id(layer, type.texture), type.atlas_coords, _rotation_to_alt(current_rotation))

func _cell_under_mouse() -> Vector2i:
	return map_to_board(base_layer.local_to_map(base_layer.get_local_mouse_position()))

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_width and cell.y < grid_height

func get_tile(cell: Vector2i, placement: int = TileType.Placement.BASE) -> Tile:
	assert(is_in_bounds(cell), "get_tile out of bounds: %s" % cell)
	return _board_for(placement)[cell.y][cell.x]

func is_empty(cell: Vector2i, placement: int = TileType.Placement.BASE) -> bool:
	return get_tile(cell, placement) == null
	
func place_tile(cell: Vector2i, tile: Tile) -> void:
	assert(is_in_bounds(cell), "place_tile out of bounds: %s" % cell)
	var placement := tile.type.placement
	assert(is_empty(cell, placement), "place_tile on occupied cell: %s" % cell)
	_board_for(placement)[cell.y][cell.x] = tile
	var layer := layer_for(tile.type)
	layer.set_cell(board_to_map(cell), _source_id(layer, tile.type.texture), tile.type.atlas_coords, _rotation_to_alt(tile.rotation))

func remove_tile(cell: Vector2i, placement: int = TileType.Placement.BASE) -> void:
	assert(is_in_bounds(cell), "remove_tile out of bounds: %s" % cell)
	var tile: Tile = get_tile(cell, placement)
	if tile == null:
		return
	_board_for(placement)[cell.y][cell.x] = null
	layer_for(tile.type).erase_cell(board_to_map(cell))
	if placement == TileType.Placement.BASE:
		# base tile carries the modifier and item stacked on it
		remove_tile(cell, TileType.Placement.MODIFIER)
		clear_item(cell)
	
func clear() -> void:
	_build_grid()
	base_layer.clear()
	items_layer.clear()
	modifiers_layer.clear()
	preview.clear()
	
func set_item(cell: Vector2i, item: Item) -> void:
	var tile := get_tile(cell)
	if tile == null:
		return
	tile.held_item = item
	refresh_item(cell)
	
func clear_item(cell: Vector2i) -> void:
	var tile := get_tile(cell)
	if tile:
		tile.held_item = null
	items_layer.erase_cell(board_to_map(cell))
	
func refresh_item(cell: Vector2i) -> void:
	var map_cell := board_to_map(cell)
	var tile := get_tile(cell)
	if tile == null or tile.held_item == null:
		items_layer.erase_cell(map_cell)
		return
	var tex: Texture2D = tile.held_item.type.tier_textures[tile.held_item.tier]
	items_layer.set_cell(map_cell, _source_id(items_layer, tex), Vector2i.ZERO, 0)
	
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
	return database.types[current_type_index]

func board_to_map(cell: Vector2i) -> Vector2i:
	return cell + GRID_ORIGIN

func map_to_board(map_cell: Vector2i) -> Vector2i:
	return map_cell - GRID_ORIGIN
