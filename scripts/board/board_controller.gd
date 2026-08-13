class_name BoardController
extends Node2D

signal path_changed

@export var belt_straight: TileType
@export var belt_corner_left: TileType
@export var belt_corner_right: TileType

@export var cell_size: int = 16

var board: Board
var session: LevelSession
var router: BeltRouter
var view: BoardView

var belt_mode: bool = true
var current_slot_index: int = 0
var current_rotation: int = 0 # 0..3

var _dragging: bool = false
var _erasing: bool = false

func _init() -> void:
	board = Board.new()
	session = LevelSession.new(board)

func _ready() -> void:
	view = BoardView.new($Base, $Items, $Modifiers, $Preview)
	router = BeltRouter.new(board, belt_straight, belt_corner_left, belt_corner_right)

func _process(_delta: float) -> void:
	_update_ghost()

func load_level(l: Level) -> void:
	session.load_level(l)
	router.configure(l.conveyors)
	view.render(board)
	path_changed.emit()

# --- INPUT ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					if belt_mode:
						_dragging = true
						if router.begin_drag(view.cell_under_mouse()):
							_apply_route()
					else:
						_handle_left_click()
				else:
					_dragging = false
					if router.end_drag():
						_apply_route()
			MOUSE_BUTTON_RIGHT:
				_erasing = event.pressed
				if event.pressed:
					_handle_right_click()
	elif event is InputEventMouseMotion:
		if _erasing:
			_handle_right_click()
		elif _dragging and belt_mode:
			if router.extend_drag(view.cell_under_mouse()):
				_apply_route()

func _handle_left_click() -> void:
	var slot := current_slot()
	if slot == null:
		return
	var cell := view.cell_under_mouse()
	if not session.can_place(cell, slot.type):
		return
	var t := Tile.new()
	t.type = slot.type
	t.rotation = _rotation_for(cell, slot.type)
	t.stat = slot.stat
	board.set_tile(cell, t)
	session.consume(slot.type)
	view.render(board)

func _handle_right_click() -> void:
	var cell := view.cell_under_mouse()
	if not board.is_in_bounds(cell):
		return
	if not board.is_empty(cell, TileType.Placement.MODIFIER):
		_remove_tile(cell, TileType.Placement.MODIFIER)
		return
	if router.erase(cell):
		_apply_route()

# --- MUTATE, THEN RE-RENDER ---

func _apply_route() -> void:
	router.apply_to_board()
	session.refund_all(board.prune_modifiers())
	view.render(board)
	path_changed.emit()
	session.inventory_changed.emit()

func _remove_tile(cell: Vector2i, placement: int = TileType.Placement.BASE) -> void:
	if board.is_locked(cell):
		return
	var tile := board.clear_tile(cell, placement)
	if tile == null:
		return
	session.refund(tile.type)
	if placement == TileType.Placement.BASE:
		var m := board.clear_tile(cell, TileType.Placement.MODIFIER)
		if m:
			session.refund(m.type)
		board.clear_item(cell)
	view.render(board)

func _update_ghost() -> void:
	var cell := view.cell_under_mouse()
	if belt_mode:
		var piece := router.preview_piece(cell)
		if piece.is_empty():
			view.hide_ghost()
		else:
			view.show_ghost(cell, piece["type"], piece["rotation"])
		return
	var slot := current_slot()
	if slot == null or not session.can_place(cell, slot.type):
		view.hide_ghost()
		return
	view.show_ghost(cell, slot.type, _rotation_for(cell, slot.type))

func current_slot() -> InventorySlot:
	if session.level == null or current_slot_index >= session.level.inventory.size():
		return null
	return session.level.inventory[current_slot_index]

func _rotation_for(cell: Vector2i, type: TileType) -> int:
	if type.placement == TileType.Placement.MODIFIER:
		var host := board.get_tile(cell, TileType.Placement.BASE)
		if host:
			return host.rotation
	return current_rotation
