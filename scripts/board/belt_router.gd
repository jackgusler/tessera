class_name BeltRouter
extends RefCounted

var flow: Dictionary = {}
var budget: int = 0

var _board: Board
var _straight: TileType
var _corner_left: TileType
var _corner_right: TileType

var _stroke: Array[Vector2i] = []
var _source_cell := Vector2i(-1, -1)
var _sink_cell := Vector2i(-1, -1)
var _source_dir: int = -1
var _sink_dir: int = -1

func _init(board: Board, straight: TileType, corner_left: TileType, corner_right: TileType) -> void:
	_board = board
	_straight = straight
	_corner_left = corner_left
	_corner_right = corner_right
	
func configure(conveyor_budget: int) -> void:
	budget = conveyor_budget
	flow.clear()
	_stroke.clear()
	_source_dir = -1
	_sink_dir = -1
	_source_cell = _board.find_cell_by_category(TileType.Category.SOURCE)
	_sink_cell = _board.find_cell_by_category(TileType.Category.SINK)
	if _board.is_in_bounds(_source_cell):
		_source_dir = Board.dir_index(_board.get_tile(_source_cell).rotated_outputs())
	if _board.is_in_bounds(_sink_cell):
		_sink_dir = (Board.dir_index(_board.get_tile(_sink_cell).rotated_inputs()) + 2) % 4

func conveyors_left() -> int:
	return budget - flow.size()

# --- PAINTING --- #

func begin_drag(cell: Vector2i) -> bool:
	_stroke.clear()
	return _paint(cell)

func extend_drag(cell: Vector2i) -> bool:
	return _paint(cell)

func end_drag() -> bool:
	if _stroke.is_empty():
		return false
	var last: Vector2i = _stroke[-1]
	_stroke.clear()
	if flow.has(last) and not _leads_somewhere(last):
		flow[last] = _default_out(last, _incoming_dir(last))
		return true
	return false

func erase(cell: Vector2i) -> bool:
	return flow.erase(cell)

func apply_to_board() -> void:
	_board.clear_unlocked_base()
	for key in flow:
		var cell: Vector2i = key
		var b: int = flow[cell]
		var a := _incoming_dir(cell)
		if a < 0 or a == (b + 2) % 4:
			a = b # unfed, or a U-turn — draw it straight
		var piece := _piece_for(a, b)
		if piece.is_empty():
			continue
		var t := Tile.new()
		t.type = piece["type"]
		t.rotation = piece["rotation"]
		_board.set_tile(cell, t)

func _paint(cell: Vector2i) -> bool:
	if not _board.is_in_bounds(cell):
		return false
	var changed := false
	if not _stroke.is_empty():
		var prev: Vector2i = _stroke[-1]
		if cell == prev:
			return false
		if _is_adjacent(prev, cell):
			flow[prev] = _dir_between(prev, cell)
			changed = true
		else:
			_stroke.clear()
	if _board.is_locked(cell):
		_stroke.clear() # generator/sink: connect into it, but don't build on it
		return true
	if not flow.has(cell):
		if flow.size() >= budget:
			return changed
		var a := _incoming_dir(cell)
		flow[cell] = _dir_between(_stroke[-1], cell) if not _stroke.is_empty() else _default_out(cell, a)
	_stroke.append(cell)
	_retarget_dangling(cell)
	return true

# --- ROUTE SOLVING --- #

func _dir_between(from: Vector2i, to: Vector2i) -> int:
	return Board.ORTHO.find(to - from)

func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var d: Vector2i = b - a
	return absi(d.x) + absi(d.y) == 1

func _incoming_dir(cell: Vector2i) -> int:
	if _source_dir >= 0 and _source_cell + Board.ORTHO[_source_dir] == cell:
		return _source_dir
	for key in flow:
		var n: Vector2i = key
		if n + Board.ORTHO[flow[n]] == cell:
			return flow[n]
	return -1

func _default_out(cell: Vector2i, a: int) -> int:
	for i in 4:
		if a >= 0 and i == (a + 2) % 4:
			continue # never point back at the feeder
		if cell + Board.ORTHO[i] == _sink_cell and i == _sink_dir:
			return i
	for i in 4:
		if a >= 0 and i == (a + 2) % 4:
			continue
		var n: Vector2i = cell + Board.ORTHO[i]
		if flow.has(n) and n + Board.ORTHO[flow[n]] != cell:
			return i # a belt that isn't already feeding us
	return a if a >= 0 else _source_dir

func _leads_somewhere(cell: Vector2i) -> bool:
	var t: Vector2i = cell + Board.ORTHO[flow[cell]]
	return t == _sink_cell or flow.has(t)

func _retarget_dangling(around: Vector2i) -> void:
	for i in 4:
		var n: Vector2i = around + Board.ORTHO[i]
		if not flow.has(n) or _leads_somewhere(n):
			continue
		if _incoming_dir(n) == i:
			continue # `around` feeds n — pointing back makes a 2-cycle
		flow[n] = (i + 2) % 4

func _piece_for(a: int, b: int) -> Dictionary:
	var type: TileType
	if b == a:
		type = _straight
	elif b == (a + 1) % 4:
		type = _corner_right
	elif b == (a + 3) % 4:
		type = _corner_left
	else:
		return {}
	return {"type": type, "rotation": (b - Board.dir_index(type.outputs) + 4) % 4}