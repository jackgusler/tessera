class_name Item
extends RefCounted

var type: ItemType
var tier: int = 0
var value: float = 0.0

static func create(item_type: ItemType, item_tier: int = 0) -> Item:
	var it = Item.new()
	it.type = item_type
	it.tier = item_tier
	it.value = item_type.tier_values[item_tier]
	return it
