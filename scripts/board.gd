class_name Board
extends Node2D
## The Clockwork board (epic TES-8, ticket TES-9).
##
## Owns a [param grid_size] grid of cells. Each cell holds a generic payload
## ([code]null[/code] = empty); later tickets store placed-tile references here.
## Coordinate helpers work in the board's LOCAL space (this node's own origin);
## convert global mouse positions with [code]to_local()[/code] before calling
## [method world_to_cell]. The data model is deliberately usable without being
## in the scene tree so the drivetrain sim (ticket 4) can be unit-tested headless.

signal cell_changed(cell: Vector2i, value: Variant)

## Board dimensions in cells. Default 6×6 is the working value pending TES-3;
## changeable in the Inspector with no code edits. Changing it resets the grid.
@export var grid_size: Vector2i = Vector2i(6, 6):
	set(value):
		grid_size = Vector2i(maxi(1, value.x), maxi(1, value.y))
		_resize_cells()
		_recenter()
		queue_redraw()

## Cell edge length in pixels (art is 16×16 — firm project decision).
@export var cell_size: int = 16:
	set(value):
		cell_size = maxi(1, value)
		_recenter()
		queue_redraw()

@export_group("Placeholder colours")
@export var bg_color: Color = Color("1b1e28")
@export var cell_color: Color = Color("2b2f3a")
@export var line_color: Color = Color("3a3f4c")

const ORTHO: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

## Flat row-major array of length grid_size.x * grid_size.y. null == empty.
var _cells: Array = []
## Debug-only cell tints (cell -> Color), drawn over the base cell colour.
var _fills: Dictionary = {}

func _ready() -> void:
	_resize_cells()
	_recenter()
	if is_inside_tree():
		get_viewport().size_changed.connect(_recenter)
	queue_redraw()

# --- Coordinate helpers -------------------------------------------------------

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y

func cell_to_world(cell: Vector2i) -> Vector2:
	## Top-left corner of the cell, in board-local space.
	return Vector2(cell.x * cell_size, cell.y * cell_size)

func cell_to_world_center(cell: Vector2i) -> Vector2:
	return cell_to_world(cell) + Vector2(cell_size, cell_size) * 0.5

func world_to_cell(local_pos: Vector2) -> Vector2i:
	## Expects a board-LOCAL position (see class note). May be out of bounds.
	return Vector2i(floori(local_pos.x / cell_size), floori(local_pos.y / cell_size))

func get_orthogonal_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in ORTHO:
		var n: Vector2i = cell + d
		if is_in_bounds(n):
			out.append(n)
	return out

func board_pixel_size() -> Vector2:
	return Vector2(grid_size.x * cell_size, grid_size.y * cell_size)

# --- Cell data ----------------------------------------------------------------

func get_cell(cell: Vector2i) -> Variant:
	assert(is_in_bounds(cell), "get_cell out of bounds: %s" % cell)
	return _cells[_index(cell)]

func is_empty(cell: Vector2i) -> bool:
	return get_cell(cell) == null

func set_cell(cell: Vector2i, value: Variant) -> void:
	assert(is_in_bounds(cell), "set_cell out of bounds: %s" % cell)
	_cells[_index(cell)] = value
	cell_changed.emit(cell, value)
	queue_redraw()

func clear_cell(cell: Vector2i) -> void:
	set_cell(cell, null)

func clear() -> void:
	for i in _cells.size():
		_cells[i] = null
	queue_redraw()

# --- Debug helpers ------------------------------------------------------------

func debug_fill(cell: Vector2i, color: Color) -> void:
	_fills[cell] = color
	queue_redraw()

func debug_clear_fills() -> void:
	_fills.clear()
	queue_redraw()

# --- Internals ----------------------------------------------------------------

func _index(cell: Vector2i) -> int:
	return cell.y * grid_size.x + cell.x

func _resize_cells() -> void:
	_cells.resize(grid_size.x * grid_size.y)
	for i in _cells.size():
		_cells[i] = null

func _recenter() -> void:
	if not is_inside_tree():
		return
	var vp: Vector2 = get_viewport_rect().size
	position = ((vp - board_pixel_size()) * 0.5).floor()

func _draw() -> void:
	var size: Vector2 = board_pixel_size()
	draw_rect(Rect2(Vector2.ZERO, size), bg_color, true)
	var inset: Vector2 = Vector2.ONE
	var cell_rect_size: Vector2 = Vector2(cell_size, cell_size) - inset * 2.0
	for y in grid_size.y:
		for x in grid_size.x:
			var c: Vector2i = Vector2i(x, y)
			var col: Color = _fills.get(c, cell_color)
			draw_rect(Rect2(cell_to_world(c) + inset, cell_rect_size), col, true)
	for x in grid_size.x + 1:
		var gx: float = float(x * cell_size)
		draw_line(Vector2(gx, 0.0), Vector2(gx, size.y), line_color, 1.0)
	for y in grid_size.y + 1:
		var gy: float = float(y * cell_size)
		draw_line(Vector2(0.0, gy), Vector2(size.x, gy), line_color, 1.0)
