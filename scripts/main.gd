extends Node2D
## Boot scene for Tessera. Instances the board; round/shop systems land later.

const BoardScene: PackedScene = preload("res://scenes/board.tscn")

func _ready() -> void:
	print("Tessera booting — Clockwork drivetrain")
	add_child(BoardScene.instantiate())
