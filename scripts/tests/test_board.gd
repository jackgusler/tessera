extends SceneTree
## Headless unit test for Board (TES-9).
## Run: Godot --headless -s res://scripts/tests/test_board.gd
## Exits 0 on success, 1 on any failed check.

func _initialize() -> void:
	var fails: Array[String] = []

	var b := Board.new()
	b.grid_size = Vector2i(6, 6)
	b.cell_size = 16

	# Bounds
	_check(fails, "in-bounds top-left", b.is_in_bounds(Vector2i(0, 0)))
	_check(fails, "in-bounds bottom-right", b.is_in_bounds(Vector2i(5, 5)))
	_check(fails, "oob +x", not b.is_in_bounds(Vector2i(6, 0)))
	_check(fails, "oob +y", not b.is_in_bounds(Vector2i(0, 6)))
	_check(fails, "oob negative", not b.is_in_bounds(Vector2i(-1, 0)))

	# Coordinate round-trip across every cell (top-left and centre)
	var roundtrip_ok := true
	for y in 6:
		for x in 6:
			var c := Vector2i(x, y)
			if b.world_to_cell(b.cell_to_world(c)) != c:
				roundtrip_ok = false
			if b.world_to_cell(b.cell_to_world_center(c)) != c:
				roundtrip_ok = false
	_check(fails, "coordinate round-trip", roundtrip_ok)

	# Neighbour counts
	_check(fails, "neighbours corner (0,0)=2", b.get_orthogonal_neighbors(Vector2i(0, 0)).size() == 2)
	_check(fails, "neighbours corner (5,5)=2", b.get_orthogonal_neighbors(Vector2i(5, 5)).size() == 2)
	_check(fails, "neighbours edge (0,3)=3", b.get_orthogonal_neighbors(Vector2i(0, 3)).size() == 3)
	_check(fails, "neighbours interior (2,2)=4", b.get_orthogonal_neighbors(Vector2i(2, 2)).size() == 4)

	# Cell data set/get/clear
	_check(fails, "cell starts empty", b.is_empty(Vector2i(2, 2)))
	b.set_cell(Vector2i(2, 2), "motor")
	_check(fails, "set/get", b.get_cell(Vector2i(2, 2)) == "motor")
	_check(fails, "occupied after set", not b.is_empty(Vector2i(2, 2)))
	b.clear_cell(Vector2i(2, 2))
	_check(fails, "empty after clear", b.is_empty(Vector2i(2, 2)))

	# clear() wipes everything
	b.set_cell(Vector2i(0, 0), "x")
	b.set_cell(Vector2i(5, 5), "y")
	b.clear()
	_check(fails, "clear() wipes all", b.is_empty(Vector2i(0, 0)) and b.is_empty(Vector2i(5, 5)))

	# Resizing rebuilds the grid
	b.grid_size = Vector2i(3, 8)
	_check(fails, "resize bounds", b.is_in_bounds(Vector2i(2, 7)) and not b.is_in_bounds(Vector2i(3, 0)))

	b.free()

	if fails.is_empty():
		print("PASS: all Board tests passed")
		quit(0)
	else:
		for f in fails:
			printerr("FAIL: ", f)
		print("FAILED: %d check(s)" % fails.size())
		quit(1)

func _check(fails: Array[String], label: String, condition: bool) -> void:
	if not condition:
		fails.append(label)
