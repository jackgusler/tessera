extends HBoxContainer

@export var board: gridContainer

func _ready() -> void:
	var group := ButtonGroup.new()
	for i in board.tile_types.size():
		var type := board.tile_types[i]
		var btn := Button.new()
		btn.text = type.display_name
		btn.toggle_mode = true
		btn.button_group = group
		btn.button_pressed = (i == board.current_type_index)
		btn.pressed.connect(_on_slot_pressed.bind(i))
		add_child(btn)

func _on_slot_pressed(index: int) -> void:
	board.current_type_index = index
