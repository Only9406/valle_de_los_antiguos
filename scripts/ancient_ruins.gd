extends Node3D

const Palette = preload("res://scripts/palette.gd")

## Ruinas de los Antiguos: plaza de piedra, altar con runa flotante,
## anillo de pilares rotos, arco de entrada y cuatro obeliscos.

var rune: Node3D
var stone: StandardMaterial3D
var dark: StandardMaterial3D
var glow: StandardMaterial3D


func build(terrain) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	# Piedra con la misma textura (forest_texture.png) que las rocas KayKit
	stone = Palette.swatch(64, 560, Color(0.6, 0.59, 0.55))
	dark = Palette.swatch(64, 720, Color(0.38, 0.38, 0.36))
	glow = _mat(Color(0.3, 0.9, 1.0))
	glow.emission_enabled = true
	glow.emission = Color(0.3, 0.9, 1.0)
	glow.emission_energy_multiplier = 2.5

	# Suelo de la plaza (cima en y = 0.2) y plataforma central (cima en y = 0.6)
	_solid(_cyl_mesh(20.5, 0.5), _cyl_shape(20.5, 0.5), Vector3(0, -0.05, 0), dark)
	_solid(_cyl_mesh(9.0, 0.4), _cyl_shape(9.0, 0.4), Vector3(0, 0.4, 0), stone)

	# Altar
	_solid(_box_mesh(Vector3(3.2, 1.1, 1.6)), _box_shape(Vector3(3.2, 1.1, 1.6)), Vector3(0, 1.15, 0), stone)

	# Runa flotante
	rune = Node3D.new()
	rune.position = Vector3(0, 3.4, 0)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.9
	ring.mesh = torus
	ring.material_override = glow
	ring.rotation_degrees.x = 90.0
	rune.add_child(ring)
	var core := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.25
	sph.height = 0.5
	core.mesh = sph
	core.material_override = glow
	rune.add_child(core)
	add_child(rune)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 3.2, 0)
	light.light_color = Color(0.4, 0.9, 1.0)
	light.light_energy = 2.0
	light.omni_range = 16.0
	add_child(light)

	# Anillo de pilares (se deja libre el hueco del camino, k = 0)
	for k in range(1, 10):
		var a := k * TAU / 10.0
		var pos := Vector3(sin(a) * 15.0, 0.2, cos(a) * 15.0)
		var broken := rng.randf() < 0.4
		var ph := rng.randf_range(2.5, 4.0) if broken else rng.randf_range(6.0, 8.5)
		_pillar(pos, ph, not broken)
		if broken:
			_solid(_cyl_mesh(0.8, 2.5), _cyl_shape(0.8, 2.5),
					pos + Vector3(rng.randf_range(-2, 2), 0.8, rng.randf_range(-2, 2)),
					dark, Vector3(0, rng.randf() * TAU, PI / 2.0))

	# Arco de entrada (lado del camino)
	_pillar(Vector3(-3.5, 0.2, 19.0), 7.0, true)
	_pillar(Vector3(3.5, 0.2, 19.0), 7.0, true)
	_solid(_box_mesh(Vector3(9.0, 1.2, 1.6)), _box_shape(Vector3(9.0, 1.2, 1.6)), Vector3(0, 8.2, 19.0), stone)

	# Obeliscos con runas
	for k in range(4):
		var a2 := PI / 4.0 + k * PI / 2.0
		var x := sin(a2) * 28.0
		var z := cos(a2) * 28.0
		var y: float = terrain.get_height(x, z)
		var ob := _solid(_box_mesh(Vector3(1.4, 9.0, 1.4)), _box_shape(Vector3(1.4, 9.0, 1.4)),
				Vector3(x, y + 4.0, z), dark, Vector3(0, a2, 0))
		var stripe := MeshInstance3D.new()
		stripe.mesh = _box_mesh(Vector3(0.25, 6.0, 1.45))
		stripe.material_override = glow
		ob.add_child(stripe)


func _process(delta: float) -> void:
	if rune:
		rune.rotation.y += delta * 0.8
		rune.position.y = 3.4 + sin(Time.get_ticks_msec() * 0.002) * 0.15


func _pillar(pos: Vector3, h: float, capital: bool) -> void:
	_solid(_box_mesh(Vector3(2.4, 0.4, 2.4)), _box_shape(Vector3(2.4, 0.4, 2.4)), pos + Vector3(0, 0.2, 0), dark)
	_solid(_cyl_mesh(0.9, h), _cyl_shape(0.9, h), pos + Vector3(0, 0.4 + h * 0.5, 0), stone)
	if capital:
		_solid(_box_mesh(Vector3(2.2, 0.5, 2.2)), _box_shape(Vector3(2.2, 0.5, 2.2)), pos + Vector3(0, 0.4 + h + 0.25, 0), dark)


func _solid(mesh: Mesh, shape: Shape3D, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = rot
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	return body


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m


func _cyl_mesh(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 24
	return c


func _cyl_shape(r: float, h: float) -> CylinderShape3D:
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	return s


func _box_mesh(sz: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = sz
	return b


func _box_shape(sz: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = sz
	return b
