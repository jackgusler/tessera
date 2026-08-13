class_name BoardView
extends RefCounted

var _base: TileMapLayer
var _items: TileMapLayer
var _modifiers: TileMapLayer
var _preview: TileMapLayer

var _source_by_texture: Dictionary = {}

func _init(base: TileMapLayer, items: TileMapLayer, mods: TileMapLayer, preview: TileMapLayer) -> void:
	_base = base
	_items = items
	_modifiers = mods
	_preview = preview
	_build_source_lookup()
	
func _build_source_lookup() -> void:
	_source_by_texture.clear()
	for layer in [_base, _items, _modifiers, _preview]:
		_source_by_texture[layer.tile_set] = _sources_for(layer.tile_set)

func _sources_for(ts: TileSet) -> Dictionary:
	var out := {}
	for i in ts.get_source_count():
		var id := ts.get_source_id(i)
		var src := ts.get_source(id) as TileSetAtlasSource
		if src and src.texture:
			out[src.texture] = id
	return out

func _source_id(layer: TileMapLayer, texture: Texture2D) -> int:
	var lookup: Dictionary = _source_by_texture.get(layer.tile_set, {})
	return lookup.get(texture, -1)

func layer_for(type: TileType) -> TileMapLayer:
	match type.placement:
		TileType.Placement.MODIFIER: return _modifiers
		_: return _base

func _rotation_to_alt(rot: int) -> int:
	match rot:
		1: return TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
		2: return TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
		3: return TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V
		_: return 0

# --- RENDERER --- #

func render(board: Board) -> void:
	_base.clear()
	_items.clear()
	_modifiers.clear()
	for y in board.grid_height:
		for x in board.grid_width:
			var map_cell := Board.board_to_map(Vector2i(x, y))
			var t: Tile = board.grid[y][x]
			if t:
				_draw(_base, map_cell, t.type, t.rotation)
				if t.held_item:
					var tex: Texture2D = t.held_item.type.tier_textures[t.held_item.tier]
					_items.set_cell(map_cell, _source_id(_items, tex), Vector2i.ZERO, 0)
			var m: Tile = board.modifiers[y][x]
			if m:
				_draw(_modifiers, map_cell, m.type, m.rotation)

func _draw(layer: TileMapLayer, map_cell: Vector2i, type: TileType, rot: int) -> void:
	var sid := _source_id(layer, type.texture)
	assert(sid >= 0, "No tileset source for '%s' on layer %s" % [type.display_name, layer.name])
	layer.set_cell(map_cell, sid, type.atlas_coords, _rotation_to_alt(rot))

func show_ghost(cell: Vector2i, type: TileType, rot: int) -> void:
	_preview.clear()
	var layer := layer_for(type)
	if _preview.tile_set != layer.tile_set:
		_preview.tile_set = layer.tile_set
	_preview.set_cell(Board.board_to_map(cell), _source_id(layer, type.texture), type.atlas_coords, _rotation_to_alt(rot))

func hide_ghost() -> void:
	_preview.clear()

func cell_under_mouse() -> Vector2i:
	return Board.map_to_board(_base.local_to_map(_base.get_local_mouse_position()))
