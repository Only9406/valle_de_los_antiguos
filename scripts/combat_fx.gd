extends RefCounted
## Efectos visuales de combate: numeros de dano flotantes y destellos de impacto.


static func damage_popup(host: Node, pos: Vector3, amount: int, crit := false, tint := Color(1, 1, 1)) -> void:
	if host == null:
		return
	var l := Label3D.new()
	l.text = ("%d!" % amount) if crit else str(amount)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.014 if crit else 0.01
	l.font_size = 64
	l.outline_size = 14
	l.modulate = Color(1.0, 0.82, 0.15) if crit else tint
	l.render_priority = 10
	host.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.6, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


static func burst(host: Node, pos: Vector3, color: Color, size := 0.8) -> void:
	if host == null:
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, 0.75)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * size * 0.3
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, 0.22)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.22)
	tw.chain().tween_callback(mi.queue_free)


## Texto flotante libre (p. ej. "NIVEL 3").
static func text_popup(host: Node, pos: Vector3, text: String, color: Color, size := 0.016) -> void:
	if host == null:
		return
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = size
	l.font_size = 64
	l.outline_size = 14
	l.modulate = color
	l.render_priority = 10
	host.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 2.2, 1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.9)
	tw.chain().tween_callback(l.queue_free)
