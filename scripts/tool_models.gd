extends RefCounted
## Modelos de las herramientas de recoleccion. El hacha usa el modelo KayKit; el pico y la
## hoz se construyen con formas simples. Todos se orientan a lo largo de +Y (empunadura en 0).

const AXE := "res://assets/kaykit_adventurers/props/axe_1handed.gltf"


static func build(tool_id: String) -> Node3D:
	var root := Node3D.new()
	match tool_id:
		"axe":
			if ResourceLoader.exists(AXE):
				root.add_child((load(AXE) as PackedScene).instantiate())
			else:
				_pickaxe(root)
		"pickaxe":
			_pickaxe(root)
		"sickle":
			_sickle(root)
	return root


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


static func _part(root: Node3D, mesh: Mesh, c: Color, pos: Vector3, rot_deg := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	root.add_child(mi)


static func _handle(root: Node3D, length: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.04
	cm.height = length
	cm.radial_segments = 8
	_part(root, cm, Color(0.5, 0.33, 0.18), Vector3(0, length * 0.5 - 0.1, 0))


static func _pickaxe(root: Node3D) -> void:
	_handle(root, 1.0)
	var metal := Color(0.66, 0.69, 0.74)
	var bar := BoxMesh.new()
	bar.size = Vector3(0.55, 0.07, 0.07)
	_part(root, bar, metal, Vector3(0, 0.9, 0))
	for side in [-1.0, 1.0]:
		var tip := CylinderMesh.new()
		tip.top_radius = 0.0
		tip.bottom_radius = 0.045
		tip.height = 0.22
		tip.radial_segments = 8
		_part(root, tip, metal, Vector3(side * 0.37, 0.88, 0), Vector3(0, 0, -side * 90.0 - 15.0 * side))


static func _sickle(root: Node3D) -> void:
	_handle(root, 0.6)
	var metal := Color(0.8, 0.82, 0.86)
	# hoja curva: arco de 5 segmentos alrededor de un centro, a un lado de la empunadura
	var center := Vector3(0.17, 0.62, 0.0)
	for a in [180.0, 150.0, 120.0, 90.0, 60.0]:
		var th := deg_to_rad(a)
		var seg := BoxMesh.new()
		seg.size = Vector3(0.1, 0.035, 0.015)
		_part(root, seg, metal, center + Vector3(cos(th), sin(th), 0.0) * 0.17, Vector3(0, 0, a + 90.0))
