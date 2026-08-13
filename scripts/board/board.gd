class_name Board
extends RefCounted

const GRID_ORIGIN := Vector2i(-3, -3)
const ORTHO: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

@export var grid_width: int = 6
@export var grid_height: int = 6

var grid: Array
var modifiers: Array
var locked: Dictionary = {}

func _init(w: int = 6, h: int = 6) -> void:
	resize(w, h)

func resize(w: int, h: int) -> void:
	grid_width = w
	grid_height = h
	clear()

func clear() -> void:
	grid = _empty_board()
	modifiers = _empty_board()
	locked.clear()

func _empty_board() -> Array:
	var board := []
	for y in grid_height:
		var row := []
		row.resize(grid_width)
		board.append(row)
	return board

func _board_for(placement: int) -> Array:
	return modifiers if placement == TileType.Placement.MODIFIER else grid

# --- QUERIES --- #

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_width and cell.y < grid_height

func is_locked(cell: Vector2i) -> bool:
	return locked.has(cell)

func get_tile(cell: Vector2i, placement: int = TileType.Placement.BASE) -> Tile:
	assert(is_in_bounds(cell), "get_tile out of bounds: %s" % cell)
	return _board_for(placement)[cell.y][cell.x]

func is_empty(cell: Vector2i, placement: int = TileType.Placement.BASE) -> bool:
	return get_tile(cell, placement) == null

func find_cell_by_category(category: int) -> Vector2i:
	for y in grid_height:
		for x in grid_width:
			var t: Tile = grid[y][x]
			if t and t.type.category == category:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in ORTHO:
		var n: Vector2i = cell + d
		if is_in_bounds(n):
			out.append(n)
	return out

# --- MUTATION --- #

func set_tile(cell: Vector2i, tile: Tile) -> void:
	assert(is_in_bounds(cell), "set_tile out of bounds: %s" % cell)
	_board_for(tile.type.placement)[cell.y][cell.x] = tile

func clear_tile(cell: Vector2i, placement: int = TileType.Placement.BASE) -> Tile:
	assert(is_in_bounds(cell), "clear_tile out of bounds: %s" % cell)
	var tile: Tile = _board_for(placement)[cell.y][cell.x]
	_board_for(placement)[cell.y][cell.x] = null
	return tile
	
func set_item(cell: Vector2i, item: Item) -> void:
	var tile := get_tile(cell)
	if tile:
		tile.held_item = item
		
func clear_item(cell: Vector2i) -> void:
	var tile := get_tile(cell)
	if tile:
		tile.held_item = null

func clear_unlocked_base() -> void:
	for y in grid_height:
		for x in grid_width:
			if not is_locked(Vector2i(x, y)):
				grid[y][x] = null
				
func prune_modifiers() -> Array[TileType]:
	var dropped: Array[TileType] = []
	for y in grid_height:
		for x in grid_width:
			var m: Tile = modifiers[y][x]
			if m == null:
				continue
			var host: Tile = grid[y][x]
			if host != null and host.type.accepts_modifiers:
				m.rotation = host.rotation
			else:
				modifiers[y][x] = null
				dropped.append(m.type)
	return dropped
	
# --- STATICS --- #

static func dir_index(mask: int) -> int:
	match mask:
		1: return 0 # Right
		2: return 1 # Down
		4: return 2 # Left
		8: return 3 # Up
		_: return -1 # zero or multi-bit

static func board_to_map(cell: Vector2i) -> Vector2i:
	return cell + GRID_ORIGIN

static func map_to_board(map_cell: Vector2i) -> Vector2i:
	return map_cell - GRID_ORIGIN
