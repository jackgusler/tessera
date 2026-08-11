extends HBoxContainer

@export var board: gridContainer

func _ready() -> void:
	board.inventory_changed.connect(_rebuild)

func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var group := ButtonGroup.new()
	for i in board.level.inventory.size():
		var slot: InventorySlot = board.level.inventory[i]
		var left := board.remaining(slot.type)
		var btn := Button.new()
		btn.text = _slot_label(slot, left)
		btn.toggle_mode = true
		btn.button_group = group
		btn.disabled = left <= 0
		btn.button_pressed = (i == board.current_slot_index)
		btn.pressed.connect(_on_slot_pressed.bind(i))
		add_child(btn)

func _on_slot_pressed(index: int) -> void:
	board.current_slot_index = index

func _slot_label(slot: InventorySlot, left: int) -> String:
	var s := ""
	match slot.type.category:
		TileType.Category.ADDER:      s = " +%s" % slot.stat
		TileType.Category.MULTIPLIER: s = " ×%s" % slot.stat
		TileType.Category.UPGRADER:   s = " ▲"
		TileType.Category.DOWNGRADER: s = " ▼"
	return "%s%s (%d)" % [slot.type.display_name, s, left]
