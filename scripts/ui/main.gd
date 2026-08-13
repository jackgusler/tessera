extends Node2D

@onready var board: BoardController = $BoardContainer

@export var levels: Array[Level]

var current_level_index: int = -1

func _ready() -> void:
	board.solved.connect(_on_solved)
	board.run_failed.connect(_on_run_failed)
	load_level(0)

func load_level(index: int) -> void:
	if index < 0 or index >= levels.size():
		return
	current_level_index = index
	board.load_level(levels[index])
	print("Level %d: %s — target %s" % [index + 1, levels[index].display_name, levels[index].target])

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ENTER:        board.check_solution()
		KEY_BRACKETRIGHT: load_level(current_level_index + 1)
		KEY_BRACKETLEFT:  load_level(current_level_index - 1)

func _on_solved(value: float) -> void:
	print("Solved with %s" % value)

func _on_run_failed(reason: String) -> void:
	print("Failed: %s" % reason)
