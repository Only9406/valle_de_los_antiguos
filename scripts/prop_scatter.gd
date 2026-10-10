extends Node3D
## Reparte arboles, rocas, arbustos y hierba por el valle usando los modelos
## KayKit. Si no hay modelos, usa formas simples para que el mundo sea jugable.

const AssetCatalog = preload("res://scripts/asset_catalog.gd")
const ResourceNode = preload("res://scripts/resource_node.gd")

## Multiplicador global de tamano. Los modelos KayKit son pequenos (un arbol
## mide 4-8 m), asi que cada categoria ya lleva su propia escala abajo.
const MODEL_SCALE := 1.0

var rng := RandomNumberGenerator.new()
var catalog
var terrain
var using_assets := false
## Zonas sin arboles/rocas/arbustos: Vector3(x, z, radio). Se usan para los campamentos.
var clearings: Array = []
## Arboles y rocas colocados: Vector3(x, z, radio). Sirve para no spawnear enemigos encima.
var blocked: Array = []


func populate(t, world_seed: int, free_zones: Array = []) -> void:
	terrain = t
	clearings = free_zones
	rng.seed = world_seed
	catalog = AssetCatalog.new()
	catalog.scan()
	using_assets = catalog.total > 0
	if using_assets:
		print("[Valle] Modelos KayKit cargados: %d (arboles %d, muertos %d, rocas %d, arbustos %d, hierba %d)" % [
			catalog.total, catalog.scenes["tree"].size(), catalog.scenes["deadtree"].size(),
			catalog.scenes["rock"].size(), catalog.scenes["bush"].size(), catalog.scenes["grass"].size()])
	else:
		push_warning("[Valle] No hay modelos en res://assets/kaykit_forest. Usando formas de relleno.")
	#            cat          n    min  max   slope maxH  scale_min scale_max collider forest
	_scatter("tree",      380, 30.0, 118.0, 0.9, 24.0, 1.4, 2.4, true, true)
	_scatter("deadtree",   14, 34.0,  80.0, 0.9, 24.0, 1.2, 1.9, true, true)
	_scatter("deadtree",   32, 80.0, 118.0, 1.2, 40.0, 1.3, 2.2, true, false)
	_scatter("rock",       80, 24.0, 120.0, 2.0, 40.0, 1.0, 2.6, true, false)
	_scatter("bush",      140, 24.0, 110.0, 0.8, 20.0, 1.4, 2.4, false, true)
	_scatter("grass",     320, 18.0, 110.0, 0.8, 20.0, 1.8, 3.0, false, false)
	_scatter_rubble()


## Devuelve true si hay un arbol o roca a menos de `margin` metros de (x, z).
func is_blocked(x: float, z: float, margin := 0.0) -> bool:
	for b in blocked:
		var bv: Vector3 = b
		if Vector2(x - bv.x, z - bv.y).length() < bv.z + margin:
			return true
	return false


## Arboles (madera), rocas (piedra) y hierba se pueden recolectar con E y la herramienta adecuada.
func _make_gatherable(prop: Node3D, cat: String) -> void:
	match cat:
		"tree", "deadtree":
			ResourceNode.register(prop, "wood")
		"rock":
			ResourceNode.register(prop, "stone")
		"grass":
			ResourceNode.register(prop, "herb")


func _in_clearing(x: float, z: float) -> bool:
	for c in clearings:
		var cv: Vector3 = c
		if Vector2(x - cv.x, z - cv.y).length() < cv.z:
			return true
	return false


func _scatter(cat: String, target: int, min_r: float, max_r: float, max_slope: float,
		max_h: float, s_min: float, s_max: float, collider: bool, forest_bias: bool) -> void:
	var placed := 0
	var attempts := 0
	while placed < target and attempts < target * 6:
		attempts += 1
		var ang := rng.randf() * TAU
		var r := sqrt(lerpf(min_r * min_r, max_r * max_r, rng.randf()))
		var x := sin(ang) * r
		var z := cos(ang) * r
		if terrain.is_on_path(x, z, 5.0):
			continue
		if cat != "grass" and _in_clearing(x, z):
			continue
		var h: float = terrain.get_height(x, z)
		if h > max_h:
			continue
		if terrain.get_slope(x, z) > max_slope:
			continue
		if forest_bias:
			var f: float = terrain.forest_noise.get_noise_2d(x, z) * 0.5 + 0.5
			if rng.randf() > f * 1.2:
				continue
		var prop := _make_prop(cat)
		if prop == null:
			return
		prop.position = Vector3(x, h - 0.05, z)
		prop.rotation.y = rng.randf() * TAU
		prop.scale = Vector3.ONE * rng.randf_range(s_min, s_max) * MODEL_SCALE
		if collider:
			var radius := _add_collider(prop, cat)
			if radius > 0.0:
				blocked.append(Vector3(x, z, radius))
		add_child(prop)
		_make_gatherable(prop, cat)
		placed += 1


## Rocas pequenas de escombro por la plaza (sin colision, para no atascar al jugador).
func _scatter_rubble() -> void:
	if not using_assets:
		return
	var pillars: Array[Vector2] = []
	for k in range(1, 10):
		var a := k * TAU / 10.0
		pillars.append(Vector2(sin(a), cos(a)) * 15.0)
	var placed := 0
	var attempts := 0
	while placed < 24 and attempts < 200:
		attempts += 1
		var ang := rng.randf_range(0.45, TAU - 0.45) # deja libre el hueco del camino (+Z)
		var r := rng.randf_range(10.5, 19.5)
		var p := Vector2(sin(ang), cos(ang)) * r
		var near_pillar := false
		for pil in pillars:
			if p.distance_to(pil) < 2.4:
				near_pillar = true
		if near_pillar:
			continue
		var prop := _make_small_rock()
		if prop == null:
			return
		prop.position = Vector3(p.x, 0.15, p.y)
		prop.rotation.y = rng.randf() * TAU
		prop.scale = Vector3.ONE * rng.randf_range(0.8, 1.6)
		add_child(prop)
		placed += 1


func _make_small_rock() -> Node3D:
	for i in 8:
		var prop := _make_prop("rock")
		if prop == null:
			return null
		if _model_aabb(prop).size.y <= 1.1:
			return prop
		prop.free()
	return null


func _make_prop(cat: String) -> Node3D:
	var holder := Node3D.new()
	var list: Array = catalog.scenes[cat]
	if using_assets and list.size() > 0:
		var scn: PackedScene = list[rng.randi() % list.size()]
		holder.add_child(scn.instantiate())
		return holder
	match cat:
		"tree":
			holder.add_child(_mesh(_cyl(0.3, 0.4, 2.0), Color(0.4, 0.27, 0.15), Vector3(0, 1.0, 0)))
			holder.add_child(_mesh(_cone(2.0, 3.0), Color(0.15, 0.4, 0.17), Vector3(0, 3.0, 0)))
			holder.add_child(_mesh(_cone(1.5, 2.5), Color(0.18, 0.45, 0.2), Vector3(0, 4.6, 0)))
		"deadtree":
			holder.add_child(_mesh(_cyl(0.1, 0.3, 4.0), Color(0.3, 0.24, 0.2), Vector3(0, 2.0, 0)))
		"rock":
			var m := _mesh(SphereMesh.new(), Color(0.5, 0.49, 0.47), Vector3(0, 0.5, 0))
			m.scale = Vector3(1.2, 0.8, 1.0)
			holder.add_child(m)
		"bush":
			var b := _mesh(SphereMesh.new(), Color(0.2, 0.5, 0.2), Vector3(0, 0.4, 0))
			b.scale = Vector3(1.0, 0.7, 1.0)
			holder.add_child(b)
		_:
			holder.free()
			return null
	return holder


## Caja delimitadora del modelo en el espacio local del prop (sin escala del prop).
func _model_aabb(prop: Node3D) -> AABB:
	var acc: Array = []
	for c in prop.get_children():
		_collect_aabb(c, Transform3D.IDENTITY, acc)
	if acc.is_empty():
		return AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))
	return acc[0]


func _collect_aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var bb: AABB = t * (n as MeshInstance3D).get_aabb()
		if acc.is_empty():
			acc.append(bb)
		else:
			acc[0] = (acc[0] as AABB).merge(bb)
	for c in n.get_children():
		_collect_aabb(c, t, acc)


## Ajusta la colision al tamano real del modelo. Devuelve el radio en metros (0 = sin colision).
func _add_collider(prop: Node3D, cat: String) -> float:
	var box := _model_aabb(prop)
	var sc := prop.scale.y
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var radius := 0.0
	if cat == "tree" or cat == "deadtree":
		# Solo el tronco: la copa no bloquea al jugador.
		var s := CylinderShape3D.new()
		s.radius = clampf(minf(box.size.x, box.size.z) * 0.12, 0.25, 0.7)
		s.height = clampf(box.size.y, 1.5, 6.0)
		cs.shape = s
		cs.position = Vector3(box.get_center().x, s.height * 0.5, box.get_center().z)
		radius = s.radius * sc + 0.6
	else:
		# Las rocas pequenas (menos de ~60 cm) se pueden pisar: sin colision.
		if box.size.y * sc < 0.6:
			body.free()
			cs.free()
			return 0.0
		var b := BoxShape3D.new()
		b.size = Vector3(box.size.x * 0.8, maxf(box.size.y, 0.3), box.size.z * 0.8)
		cs.shape = b
		cs.position = box.get_center()
		radius = maxf(box.size.x, box.size.z) * 0.5 * sc
	body.add_child(cs)
	prop.add_child(body)
	return radius


func _mesh(m: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mi.material_override = mat
	mi.position = pos
	return mi


func _cyl(r_top: float, r_bot: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 8
	return c


func _cone(r: float, h: float) -> CylinderMesh:
	return _cyl(0.0, r, h)
