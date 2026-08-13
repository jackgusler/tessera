class_name Simulator
extends RefCounted

const MAX_STEPS := 256

class Result extends RefCounted:
	var success: bool = false
	var value: float = 0.0
	var tier: int = 0
	var path: Array[Vector2i] = []
	var error: String = ""

static func run(board: Board) -> Result:
	var res := Result.new()
	
	var cell := board.find_cell_by_category(TileType.Category.SOURCE)
	if cell.x < 0:
		res.error = "No generator on the board."
		return res
		
	var source: Tile = board.get_tile(cell)
	if source.type.emits == null:
		res.error = "Generator has no item type."
		return res
	
	var item := Item.create(source.type.emits, 0)
	res.path.append(cell)
	
	for _steps in MAX_STEPS:
		var tile: Tile = board.get_tile(cell)
		var out_mask := tile.rotated_outputs()
		if out_mask == 0:
			res.error = "Tile at %s has no output." % cell
			return res
		var dir_index := Board.dir_index(out_mask)
		if dir_index < 0:
			res.error = "Tile at %s has multiple outputs (mask %d)." % [cell, out_mask]
			return res
			
		var next: Vector2i = cell + Board.ORTHO[dir_index]
		if not board.is_in_bounds(next):
			res.error = "Path runs off the board at %s." % next
			return res
			
		var next_tile: Tile = board.get_tile(next)
		if next_tile == null:
			res.error = "Gap in the path at %s." % next
			return res
		if (next_tile.rotated_inputs() & _opposite(1 << dir_index)) == 0:
			res.error = "Tile at %s won't accept input from %s." % [next, cell]
			return res
			
		cell = next
		res.path.append(cell)
		
		var modifier: Tile = board.get_tile(cell, TileType.Placement.MODIFIER)
		if modifier:
			_apply(modifier, item)
			
		if next_tile.type.category == TileType.Category.SINK:
			res.success = true
			res.tier = item.tier
			res.value = item.value * item.type.tier_values[item.tier]
			return res
			
	res.error = "Path loops."
	return res
	
static func _opposite(bit: int) -> int:
	return ((bit << 2) | (bit >> 2)) & 0b1111

static func _shift_tier(item: Item, delta: int) -> void:
	var next := clampi(item.tier + delta, 0, item.type.max_tier())
	if next == item.tier:
		return
	var from: float = item.type.tier_values[item.tier]
	if from != 0.0:
		item.value *= item.type.tier_values[next] / from
	item.tier = next

static func _apply(tile: Tile, item: Item) -> void:
	match tile.type.category:
		TileType.Category.ADDER:      item.value += tile.stat
		TileType.Category.MULTIPLIER: item.value *= tile.stat
		TileType.Category.UPGRADER:   _shift_tier(item, 1)
		TileType.Category.DOWNGRADER: _shift_tier(item, -1)
		TileType.Category.SPLITTER:   pass
