extends Node3D
## Ataque de zona con retardo (Meteoro, Lluvia de flechas): muestra un circulo en el
## suelo, y al terminar la cuenta atras golpea a los enemigos dentro del radio.

const CombatFx = preload("res://scripts/combat_fx.gd")

var radius := 5.0
var delay := 1.0
var color := Color(1.0, 0.4, 0.1)
var mult := 1.0
var extra := {}
var fall := false
var shooter: Node3D
var _t := 0.0
var _ring: MeshInstance3D
var _rock: MeshInstance3D


func _ready() -> void:
	_ring = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.05
	cm.radial_segments = 32
	_ring.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, 0.3)
	_ring.material_override = m
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = 0.15
	add_child(_ring)
	if fall:
		_rock = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.9
		sm.height = 1.8
		_rock.mesh = sm
		var rm := StandardMaterial3D.new()
		rm.albedo_color = color
		rm.emission_enabled = true
		rm.emission = color
		rm.emission_energy_multiplier = 3.0
		_rock.material_override = rm
		_rock.position.y = 30.0
		add_child(_rock)
		var tw := _rock.create_tween()
		tw.tween_property(_rock, "position:y", 1.0, delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _physics_process(delta: float) -> void:
	_t += delta
	# el circulo "late" mientras se acerca el impacto
	if _ring != null:
		var s := 1.0 + 0.03 * sin(_t * 18.0)
		_ring.scale = Vector3(s, 1.0, s)
	if _t >= delay:
		_impact()


func _impact() -> void:
	set_physics_process(false)
	var scene := get_tree().current_scene
	CombatFx.burst(scene, global_position + Vector3(0, 1.0, 0), color, radius * 1.6)
	if shooter != null and is_instance_valid(shooter):
		for e in get_tree().get_nodes_in_group("enemigos"):
			if e.dead:
				continue
			var d := Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length()
			if d <= radius:
				shooter.deal_damage(e, mult, extra)
	queue_free()
