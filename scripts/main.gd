extends Node2D
## Boot scene for Tessera. Placeholder until the board/round systems land.

func _ready() -> void:
	print("Tessera booting — grid tile-placement synergy roguelike scaffold OK")
	var t := Tile.new()
	t.source_id = 1
	place_tile(Vector2i(0, 0), t)   # should paint at tilemap cell (-3,-3)
