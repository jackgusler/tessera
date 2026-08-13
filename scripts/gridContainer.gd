class_name gridContainer
extends Node2D

signal inventory_changed
signal solved(value: float)
signal run_failed(reason: String)

@onready var grid_layer: TileMapLayer = $Grid
@onready var base_layer: TileMapLayer = $Base
@onready var items_layer: TileMapLayer = $Items
@onready var modifiers_layer: TileMapLayer = $Modifiers
@onready var preview: TileMapLayer = $Preview

@export var belt_straight: TileType
@export var belt_corner_left: TileType
@export var belt_corner_right: TileType

@export var database: TileDatabase
@export var grid_width: int = 6
@export var grid_height: int = 6
@export var cell_size: int = 16

@export var level: Level
var _remaining: Dictionary = {}
var _locked: Dictionary = {}

signal path_changed

var _path: Array[Vector2i] = []
var _source_cell := Vector2i(-1, -1)
var _sink_cell := Vector2i(-1, -1)
var _source_dir: int = -1 # direction index leaving the generator
var _sink_dir: int = -1 # direction index travelling INTO the sink
var _dragging: bool = false
var belt_mode: bool = true

var _source_by_texture: Dictionary = {}

var current_type_index: int = 0
var current_rotation: int = 0 # 0..3

var current_slot_index: int = 0

const GRID_ORIGIN := Vector2i(-3, -3)
const ORTHO: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var grid: Array
var modifiers: Array

func _process(_delta: float) -> void:
	_update_ghost()

func _ready() -> void:
	_build_source_lookup()
	_build_grid()

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
	
func load_level(l: Level) -> void:
	level = l
	grid_width = l.grid_width
	grid_height = l.grid_height
	clear()
	_locked.clear()
	_remaining.clear()
	for placed in l.fixed_tiles:
		var t := Tile.new()
		t.type = placed.type
		t.rotation = placed.rotation
		t.stat = placed.stat
		_put_tile(placed.cell, t)
		_locked[placed.cell] = true
	for slot in l.inventory:
		_remaining[slot.type] = slot.count
	inventory_changed.emit()
	_path.clear()
	_source_cell = find_cell_by_category(TileType.Category.SOURCE)
	_sink_cell = find_cell_by_category(TileType.Category.SINK)
	_source_dir = dir_index(get_tile(_source_cell).rotated_outputs())
	_sink_dir = (dir_index(get_tile(_sink_cell).rotated_inputs()) + 2) % 4
	

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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if belt_mode:
				_begin_drag(_cell_under_mouse())
			else:
				_handle_left_click()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_extend_drag(_cell_under_mouse())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click()
		current_rotation = (current_rotation + 1) % 4

func can_place(cell: Vector2i, type: TileType) -> bool:
	if not is_in_bounds(cell):
		return false
	if _locked.has(cell):
		return false
	if _remaining.get(type, 0) <= 0:
		return false
	if not is_empty(cell, type.placement):
		return false
	if type.placement == TileType.Placement.MODIFIER:
		var host := get_tile(cell, TileType.Placement.BASE)
		return host != null and host.type.accepts_modifiers
	return true

func current_slot() -> InventorySlot:
	if level == null or current_slot_index >= level.inventory.size():
		return null
	return level.inventory[current_slot_index]

func _handle_left_click() -> void:
	var slot := current_slot()
	if slot == null:
		return
	var cell := _cell_under_mouse()
	if not can_place(cell, slot.type):
		return
	var t := Tile.new()
	t.type = slot.type
	t.rotation = _rotation_for(cell, slot.type)
	t.stat = slot.stat
	place_tile(cell, t)

func _handle_right_click() -> void:
	var cell := _cell_under_mouse()
	if not is_in_bounds(cell):
		return
	if not is_empty(cell, TileType.Placement.MODIFIER):
		remove_tile(cell, TileType.Placement.MODIFIER)
		return
	var i := _path.find(cell)
	if i >= 0:
		_truncate_to(i)
	
func _update_ghost() -> void:
	preview.clear()
	var slot := current_slot()
	if slot == null:
		return
	var cell := _cell_under_mouse()
	if not can_place(cell, slot.type):
		return

	var rot := current_rotation
	if slot.type.placement == TileType.Placement.MODIFIER:
		rot = get_tile(cell, TileType.Placement.BASE).rotation

	var layer := layer_for(slot.type)
	if preview.tile_set != layer.tile_set:
		preview.tile_set = layer.tile_set
	preview.set_cell(board_to_map(cell), _source_id(layer, slot.type.texture), slot.type.atlas_coords, _rotation_to_alt(rot))

func _cell_under_mouse() -> Vector2i:
	return map_to_board(base_layer.local_to_map(base_layer.get_local_mouse_position()))

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_width and cell.y < grid_height

func find_cell_by_category(category: int) -> Vector2i:
	for y in grid_height:
		for x in grid_width:
			var t: Tile = grid[y][x]
			if t and t.type.category == category:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func get_tile(cell: Vector2i, placement: int = TileType.Placement.BASE) -> Tile:
	assert(is_in_bounds(cell), "get_tile out of bounds: %s" % cell)
	return _board_for(placement)[cell.y][cell.x]

func is_empty(cell: Vector2i, placement: int = TileType.Placement.BASE) -> bool:
	return get_tile(cell, placement) == null
	
func place_tile(cell: Vector2i, tile: Tile) -> void:
	assert(is_in_bounds(cell), "place_tile out of bounds: %s" % cell)
	assert(is_empty(cell, tile.type.placement), "place_tile on occupied cell: %s" % cell)
	_put_tile(cell, tile)
	if _remaining.has(tile.type):
		_remaining[tile.type] -= 1
		inventory_changed.emit()

func _put_tile(cell: Vector2i, tile: Tile) -> void:
	_board_for(tile.type.placement)[cell.y][cell.x] = tile
	var layer := layer_for(tile.type)
	var sid := _source_id(layer, tile.type.texture)
	assert(sid >= 0, "No tileset source for '%s' on layer %s" % [tile.type.display_name, layer.name])
	layer.set_cell(board_to_map(cell), sid, tile.type.atlas_coords, _rotation_to_alt(tile.rotation))

func remove_tile(cell: Vector2i, placement: int = TileType.Placement.BASE) -> void:
	assert(is_in_bounds(cell), "remove_tile out of bounds: %s" % cell)
	if _locked.has(cell):
		return
	var tile: Tile = get_tile(cell, placement)
	if tile == null:
		return
	_board_for(placement)[cell.y][cell.x] = null
	layer_for(tile.type).erase_cell(board_to_map(cell))
	if _remaining.has(tile.type):
		_remaining[tile.type] += 1
		inventory_changed.emit()
	if placement == TileType.Placement.BASE:
		remove_tile(cell, TileType.Placement.MODIFIER)
		clear_item(cell)

func remaining(type: TileType) -> int:
	return _remaining.get(type, 0)

func check_solution() -> void:
	for slot in level.inventory:
		if slot.type.placement == TileType.Placement.MODIFIER and remaining(slot.type) > 0:
			run_failed.emit("Every modifier has to be used.")
			return
	var res := Simulator.run(self)
	if not res.success:
		run_failed.emit(res.error)
		return
	if absf(res.value - level.target) < 0.001:
		solved.emit(res.value)
	else:
		run_failed.emit("Output was %s, target is %s." % [res.value, level.target])

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
	
static func dir_index(mask: int) -> int:
	match mask:
		1: return 0 # Right
		2: return 1 # Down
		4: return 2 # Left
		8: return 3 # Up
		_: return -1 # zero or multi-bit
	return -1

func path_head() -> Vector2i:
	return _path[-1] if not _path.is_empty() else _source_cell

func _final_belt_cell() -> Vector2i:
	return _sink_cell - ORTHO[_sink_dir]

func conveyors_left() -> int:
	return level.conveyors - _path.size()

func _dir_between(from: Vector2i, to: Vector2i) -> int:
	return ORTHO.find(to - from)

func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var d: Vector2i = b - a
	return absi(d.x) + absi(d.y) == 1

func _piece_for(a: int, b: int) -> Dictionary:
	if b == a:
		return {"type": belt_straight, "rotation": (b + 1) % 4}
	if b == (a + 1) % 4:
		return {"type": belt_corner_right, "rotation": b}
	if b == (a + 3) % 4:
		return {"type": belt_corner_left, "rotation": (b + 2) % 4}
	return {}

func _begin_drag(cell: Vector2i) -> void:
	_dragging = true
	if cell == _source_cell:
		_truncate_to(0)
		return
	var i := _path.find(cell)
	if i >= 0:
		_truncate_to(i + 1)
		return
	_try_append(cell)

func _extend_drag(cell: Vector2i) -> void:
	if not is_in_bounds(cell):
		return
	if _path.size() >= 2 and cell == _path[-2]:
		_truncate_to(_path.size() - 1)
		return
	if _path.size() == 1 and cell == _source_cell:
		_truncate_to(0)
		return
	_try_append(cell)

func _try_append(cell: Vector2i) -> void:
	if level == null or _path.size() >= level.conveyors:
		return
	if _path.size() >= level.conveyors:
		return
	if cell == _source_cell or cell == _sink_cell or _path.has(cell):
		return
	if not _is_adjacent(path_head(), cell):
		return
	if _path.is_empty() and cell != _source_cell + ORTHO[_source_dir]:
		return
	_path.append(cell)
	_rebuild_path()

func _truncate_to(size: int) -> void:
	if size >= _path.size():
		return
	_path.resize(size)
	_rebuild_path()

func _rebuild_path() -> void:
	for y in grid_height:
		for x in grid_width:
			var c := Vector2i(x, y)
			if _locked.has(c) or grid[y][x] == null:
				continue
			grid[y][x] = null
			base_layer.erase_cell(board_to_map(c))

	var final_cell := _final_belt_cell()
	for i in _path.size():
		var cell: Vector2i = _path[i]
		var prev: Vector2i = _source_cell if i == 0 else _path[i - 1]
		var a := _dir_between(prev, cell)
		var b := a
		if i + 1 < _path.size():
			b = _dir_between(cell, _path[i + 1])
		elif cell == final_cell:
			b = _sink_dir
		var piece := _piece_for(a, b)
		if piece.is_empty():
			continue
		var t := Tile.new()
		t.type = piece["type"]
		t.rotation = piece["rotation"]
		_put_tile(cell, t)

	_sync_modifiers()
	path_changed.emit()
	inventory_changed.emit()

func _sync_modifiers() -> void:
	for y in grid_height:
		for x in grid_width:
			var m: Tile = modifiers[y][x]
			if m == null:
				continue
			var cell := Vector2i(x, y)
			var host: Tile = grid[y][x]
			if host != null and host.type.accepts_modifiers:
				m.rotation = host.rotation
				modifiers_layer.set_cell(board_to_map(cell), _source_id(modifiers_layer, m.type.texture), m.type.atlas_coords, _rotation_to_alt(m.rotation))
			else:
				modifiers[y][x] = null
				modifiers_layer.erase_cell(board_to_map(cell))
				if _remaining.has(m.type):
					_remaining[m.type] += 1

func _rotation_for(cell: Vector2i, type: TileType) -> int:
	if type.placement == TileType.Placement.MODIFIER:
		var host := get_tile(cell, TileType.Placement.BASE)
		if host:
			return host.rotation
	return current_rotation
	
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
