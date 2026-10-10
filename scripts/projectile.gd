extends Node3D
## Proyectil (flecha, virote u orbe magico). Avanza en linea recta, golpea al primer
## enemigo que toque (radio generoso) y desaparece al chocar con el escenario.

const CombatFx = preload("res://scripts/combat_fx.gd")
const ARROW := "res://assets/kaykit_adventurers/props/arrow_bow.gltf"
const BOLT := "res://assets/kaykit_adventurers/props/arrow_crossbow.gltf"

var kind := "arrow"
var color := Color.WHITE
var direction := Vector3.FORWARD
var speed := 30.0
var life := 1.0
var shooter: Node3D
var hit_radius := 0.9
var dmg_mult := 1.0
var explode := 0.0 # radio de explosion (0 = impacto simple)
var extra := {}    # efectos: stun / slow / dot


func _ready() -> void:
	match kind:
		"arrow":
			_add_model(ARROW)
		"bolt":
			_add_model(BOLT)
		_:
			_add_orb()
	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.98 else Vector3.RIGHT)


func _add_model(path: String) -> void:
	if ResourceLoader.exists(path):
		var m := (load(path) as PackedScene).instantiate() as Node3D
		m.rotation.y = PI # la punta del modelo esta en +Z; look_at apunta con -Z
		m.scale = Vector3.ONE * 1.3
		add_child(m)
	else:
		_add_orb()


func _add_orb() -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 4.0
	light.light_energy = 1.5
	add_child(light)


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from + direction * speed * delta
	var seg := to - from
	for e in get_tree().get_nodes_in_group("enemigos"):
		if e.dead:
			continue
		var c: Vector3 = e.global_position + Vector3(0, 1.0, 0)
		var t := clampf((c - from).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
		var closest := from + seg * t
		if closest.distance_to(c) < hit_radius:
			_impact(e, closest)
			return
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	if shooter != null and is_instance_valid(shooter):
		q.exclude = [shooter.get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		_impact(null, r["position"])
		return
	global_position = to
	life -= delta
	if life <= 0.0:
		queue_free()


func _impact(enemy, pos: Vector3) -> void:
	var scene := get_tree().current_scene
	var ok := shooter != null and is_instance_valid(shooter)
	if explode > 0.0:
		CombatFx.burst(scene, pos, color, explode * 1.8)
		if ok:
			for e2 in get_tree().get_nodes_in_group("enemigos"):
				if e2.dead:
					continue
				var d := Vector2(e2.global_position.x - pos.x, e2.global_position.z - pos.z).length()
				if d <= explode:
					shooter.deal_damage(e2, dmg_mult, extra)
	else:
		if enemy != null and ok:
			shooter.deal_damage(enemy, dmg_mult, extra)
		CombatFx.burst(scene, pos, color, 0.6 if enemy != null else 0.4)
	queue_free()
