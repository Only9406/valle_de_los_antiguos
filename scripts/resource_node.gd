extends RefCounted
## Utilidades para convertir un arbol/roca/hierba del escenario en un nodo recolectable.

const ItemData = preload("res://scripts/item_data.gd")


static func register(node: Node3D, kind: String) -> void:
	node.set_meta("gather", kind)
	node.set_meta("charges", int(ItemData.GATHER[kind]["charges"]))
	node.set_meta("base_scale", node.scale)
	node.add_to_group("recolectable")


static func has_charges(node: Node) -> bool:
	return int(node.get_meta("charges", 0)) > 0


## Consume una carga del nodo. Al agotarse se encoge, desaparece y reaparece mas tarde.
static func harvest(node: Node3D) -> void:
	var charges := int(node.get_meta("charges", 0)) - 1
	node.set_meta("charges", charges)
	if charges <= 0:
		_deplete(node)
	else:
		var base: Vector3 = node.get_meta("base_scale")
		var tw := node.create_tween()
		tw.tween_property(node, "scale", base * 0.93, 0.08)
		tw.tween_property(node, "scale", base, 0.12)


static func _deplete(node: Node3D) -> void:
	_set_collision(node, false)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE * 0.01, 0.4)
	tw.tween_callback(_hide.bind(node))
	var kind := String(node.get_meta("gather"))
	node.get_tree().create_timer(float(ItemData.GATHER[kind]["respawn"])).timeout.connect(_respawn.bind(node))


static func _hide(node: Node3D) -> void:
	if is_instance_valid(node):
		node.visible = false


static func _respawn(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	var kind := String(node.get_meta("gather"))
	node.set_meta("charges", int(ItemData.GATHER[kind]["charges"]))
	node.scale = Vector3.ONE * 0.01
	node.visible = true
	var tw := node.create_tween()
	tw.tween_property(node, "scale", node.get_meta("base_scale"), 0.6)
	_set_collision(node, true)


static func _set_collision(node: Node3D, on: bool) -> void:
	for c in node.get_children():
		if c is StaticBody3D:
			(c as StaticBody3D).set_deferred("collision_layer", 1 if on else 0)
