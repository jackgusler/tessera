class_name Simulator
extends RefCounted

const MAX_STEPS := 256

class Result extends RefCounted:
	var success: bool = false
	var value: float = 0.0
	var tier: int = 0
	var path: Array[Vector2i] = []
	var error: String = ""

static func run(board: gridContainer) -> Result:
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
	item.value = source.type.amount
	res.path.append(cell)
	
	for _steps in MAX_STEPS:
		var tile: Tile = board.get_tile(cell)
		var dir_index := _single_dir(tile.rotated_outputs())
		if dir_index < 0:
			res.error = "Dead end at %s." % cell
			return res
			
		var next: Vector2i = cell + gridContainer.ORTHO[dir_index]
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
			_apply(modifier.type, item)
			
		if next_tile.type.category == TileType.Category.SINK:
			res.success = true
			res.tier = item.tier
			res.value = item.value * item.type.tier_values[item.tier]
			return res
			
	res.error = "Path loops."
	return res

static func _single_dir(mask: int) -> int:
	var found := -1
	for i in 4:
		if mask & (1 << i):
			if found >= 0:
				return -1
			found = -1
	return found
	
static func _opposite(bit: int) -> int:
	return ((bit << 2) | (bit >> 2)) & 0b1111
	
static func _apply(type: TileType, item: Item) -> void:
	match type.category:
		TileType.Category.ADDER:      item.value += type.amount
		TileType.Category.MULTIPLIER: item.value *= type.amount
		TileType.Category.UPGRADER:   item.tier = mini(item.tier + 1, item.type.max_tier())
		TileType.Category.DOWNGRADER: item.tier = maxi(item.tier - 1, 0)
		TileType.Category.SPLITTER:   pass
