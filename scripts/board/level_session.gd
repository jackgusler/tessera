class_name LevelSession
extends RefCounted

signal inventory_changed
signal solved(value: float)
signal run_failed(reason: String)

var level: Level

var _board: Board
var _remaining: Dictionary = {} # TileType -> int

func _init(board: Board) -> void:
	_board = board

func load_level(l: Level) -> void:
	level = l
	_remaining.clear()
	_board.resize(l.grid_width, l.grid_height)
	for placed in l.fixed_tiles:
		var t := Tile.new()
		t.type = placed.type
		t.rotation = placed.rotation
		t.stat = placed.stat
		_board.set_tile(placed.cell, t)
		_board.locked[placed.cell] = true
	for slot in l.inventory:
		_remaining[slot.type] = slot.count
	inventory_changed.emit()
	
func check_solution() -> void:
	for slot in level.inventory:
		if slot.type.placement == TileType.Placement.MODIFIER and remaining(slot.type) > 0:
			run_failed.emit("Every modifier has to be used.")
			return
	var res := Simulator.run(_board)
	if not res.success:
		run_failed.emit(res.error)
		return
	if absf(res.value - level.target) < 0.001:
		solved.emit(res.value)
	else:
		run_failed.emit("Output was %s, target is %s." % [res.value, level.target])

# --- PLACEMENT RULES --- #

func remaining(type: TileType) -> int:
	return _remaining.get(type, 0)

func can_place(cell: Vector2i, type: TileType) -> bool:
	if not _board.is_in_bounds(cell):
		return false
	if _board.is_locked(cell):
		return false
	if _remaining.get(type, 0) <= 0:
		return false
	if not _board.is_empty(cell, type.placement):
		return false
	if type.placement == TileType.Placement.MODIFIER:
		var host := _board.get_tile(cell, TileType.Placement.BASE)
		return host != null and host.type.accepts_modifiers
	return true

# --- INVENTORY BOOKEEPING --- #

func consume(type: TileType) -> void:
	if _remaining.has(type):
		_remaining[type] -= 1
		inventory_changed.emit()

func refund(type: TileType) -> void:
	if _remaining.has(type):
		_remaining[type] += 1
		inventory_changed.emit()

func refund_all(types: Array[TileType]) -> void:
	if types.is_empty():
		return
	for type in types:
		if _remaining.has(type):
			_remaining[type] += 1
	inventory_changed.emit()
