extends HBoxContainer

@export var board: BoardController

func _ready() -> void:
	board.session.inventory_changed.connect(_rebuild)

func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var group := ButtonGroup.new()

	var belt_btn := Button.new()
	belt_btn.text = "Conveyors (%d)" % board.router.conveyors_left()
	belt_btn.toggle_mode = true
	belt_btn.button_group = group
	belt_btn.button_pressed = board.belt_mode
	belt_btn.pressed.connect(_on_belt_pressed)
	add_child(belt_btn)

	if board.session.level == null:
		return

	for i in board.session.level.inventory.size():
		var slot: InventorySlot = board.session.level.inventory[i]
		var left := board.session.remaining(slot.type)
		var btn := Button.new()
		btn.text = _slot_label(slot, left)
		btn.toggle_mode = true
		btn.button_group = group
		btn.disabled = left <= 0
		btn.button_pressed = (not board.belt_mode) and i == board.current_slot_index
		btn.pressed.connect(_on_slot_pressed.bind(i))
		add_child(btn)

func _slot_label(slot: InventorySlot, left: int) -> String:
	var s := ""
	match slot.type.category:
		TileType.Category.ADDER: s = " +%s" % slot.stat
		TileType.Category.MULTIPLIER: s = " ×%s" % slot.stat
		TileType.Category.UPGRADER: s = " ▲"
		TileType.Category.DOWNGRADER: s = " ▼"
	return "%s%s (%d)" % [slot.type.display_name, s, left]

func _on_belt_pressed() -> void:
	board.belt_mode = true

func _on_slot_pressed(index: int) -> void:
	board.belt_mode = false
	board.current_slot_index = index
