extends Control
## Pantalla de creacion de personaje: nombre, clase, arma, aspecto y color, con vista
## previa 3D animada (puedes arrastrar con el raton para girar al personaje).

const ClassData = preload("res://scripts/class_data.gd")
const CharacterActor = preload("res://scripts/character_actor.gd")
const AttackData = preload("res://scripts/attack_data.gd")

const NAMES := ["Aldric", "Brenna", "Cael", "Dara", "Eryn", "Fenrir", "Gwen", "Hakon", "Isolde",
	"Joren", "Kael", "Lyra", "Marek", "Nyx", "Orin", "Petra", "Quinn", "Rowan", "Sigrid", "Thane"]

var ch := {}
var name_edit: LineEdit
var class_row: HFlowContainer
var desc_label: Label
var weapon_box: VBoxContainer
var weapon_desc: Label
var look_row: HFlowContainer
var color_row: HFlowContainer
var color_name: Label
var stat_bars := {}
var stat_values := {}
var continue_btn: Button

var preview_root: Node3D
var preview_actor
var view_yaw := 0.0
var dragging := false
var spin_time := 0.0
var preview_token := 0


func _ready() -> void:
	GameState.ui_open = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if GameState.character.is_empty():
		ch = GameState.default_character()
	else:
		ch = GameState.character.duplicate()
	_build_ui()
	_build_preview()
	_refresh_all()


func _process(delta: float) -> void:
	if preview_root == null:
		return
	spin_time += delta
	if not dragging:
		view_yaw = sin(spin_time * 0.6) * 0.5
	preview_root.rotation.y = PI + view_yaw


## ----------------------------------------------------------------- interfaz
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	# ---- panel izquierdo
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.17, 0.97)
	sb.set_content_margin_all(18)
	sb.border_color = Color(0.35, 0.3, 0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)

	var title := Label.new()
	title.text = "CREA TU HÉROE"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	col.add_child(title)

	continue_btn = Button.new()
	continue_btn.custom_minimum_size = Vector2(0, 40)
	continue_btn.pressed.connect(_on_continue)
	col.add_child(continue_btn)
	var save := GameState.peek_save()
	if save.is_empty():
		continue_btn.visible = false
	else:
		var info := ClassData.info(String(save.get("class", "Knight")))
		continue_btn.text = "Continuar con %s (%s, nivel %d)" % [
			save.get("name", "Aventurero"), info["name"], int(save.get("level", 1))]

	col.add_child(_section("Nombre"))
	var nrow := HBoxContainer.new()
	name_edit = LineEdit.new()
	name_edit.max_length = 16
	name_edit.placeholder_text = "Nombre del héroe"
	name_edit.text = String(ch.get("name", ""))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(t): ch["name"] = t)
	nrow.add_child(name_edit)
	var rnd := Button.new()
	rnd.text = "Aleatorio"
	rnd.pressed.connect(_on_random_name)
	nrow.add_child(rnd)
	col.add_child(nrow)

	col.add_child(_section("Clase"))
	class_row = HFlowContainer.new()
	col.add_child(class_row)
	desc_label = Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(440, 0)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	col.add_child(desc_label)

	col.add_child(_section("Arma"))
	weapon_box = VBoxContainer.new()
	col.add_child(weapon_box)
	weapon_desc = Label.new()
	weapon_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapon_desc.custom_minimum_size = Vector2(440, 0)
	weapon_desc.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	col.add_child(weapon_desc)

	col.add_child(_section("Aspecto"))
	look_row = HFlowContainer.new()
	col.add_child(look_row)

	col.add_child(_section("Color de prenda"))
	color_row = HFlowContainer.new()
	col.add_child(color_row)
	color_name = Label.new()
	color_name.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	col.add_child(color_name)

	col.add_child(_section("Estadísticas"))
	for key in ["Vida", "Daño", "Velocidad de ataque", "Alcance", "Movimiento"]:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = key
		l.custom_minimum_size = Vector2(150, 0)
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.custom_minimum_size = Vector2(190, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var v := Label.new()
		v.custom_minimum_size = Vector2(80, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)
		col.add_child(row)
		stat_bars[key] = bar
		stat_values[key] = v

	var test := Button.new()
	test.text = "Probar ataque"
	test.custom_minimum_size = Vector2(0, 38)
	test.pressed.connect(_preview_attack)
	col.add_child(test)

	var start := Button.new()
	start.text = "COMENZAR AVENTURA"
	start.custom_minimum_size = Vector2(0, 54)
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(_on_start)
	col.add_child(start)

	# ---- zona de vista previa 3D (derecha)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.gui_input.connect(_on_preview_input)
	right.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	preview_root = Node3D.new()
	vp.add_child(preview_root)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.11, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.7, 0.85)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	vp.add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.0, 2.0, -2.5)
	rim.light_color = Color(0.5, 0.65, 1.0)
	rim.light_energy = 1.5
	rim.omni_range = 8.0
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 38.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.25, 4.4), Vector3(0, 0.95, 0))
	# Plataforma
	var plat := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.2
	cyl.bottom_radius = 1.3
	cyl.height = 0.12
	plat.mesh = cyl
	plat.position.y = -0.06
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.25, 0.27, 0.33)
	pm.roughness = 0.9
	plat.material_override = pm
	vp.add_child(plat)

	var hint := Label.new()
	hint.text = "Arrastra con el ratón para girar al personaje"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	right.add_child(hint)


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	return l


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## --------------------------------------------------------------- refrescos
func _refresh_all() -> void:
	_fill_classes()
	_fill_options()
	_update_stats()
	_rebuild_preview()


func _fill_classes() -> void:
	_clear(class_row)
	var group := ButtonGroup.new()
	for id in ClassData.ORDER:
		var b := Button.new()
		b.text = ClassData.CLASSES[id]["name"]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(92, 40)
		b.button_pressed = (id == String(ch["class"]))
		b.pressed.connect(_on_class.bind(id))
		class_row.add_child(b)
	var info := ClassData.info(String(ch["class"]))
	desc_label.text = "%s — %s" % [info["role"], info["desc"]]


func _fill_options() -> void:
	var info := ClassData.info(String(ch["class"]))
	# armas
	_clear(weapon_box)
	var wgroup := ButtonGroup.new()
	var weapons: Array = info["weapons"]
	for i in weapons.size():
		var b := Button.new()
		b.text = weapons[i]["name"]
		b.toggle_mode = true
		b.button_group = wgroup
		b.custom_minimum_size = Vector2(0, 36)
		b.button_pressed = (i == int(ch["weapon"]))
		b.pressed.connect(_on_weapon.bind(i))
		weapon_box.add_child(b)
	weapon_desc.text = String(ClassData.weapon_of(ch)["desc"])
	# aspectos
	_clear(look_row)
	var lgroup := ButtonGroup.new()
	var looks: Array = info["looks"]
	for i in looks.size():
		var b := Button.new()
		b.text = looks[i]["name"]
		b.toggle_mode = true
		b.button_group = lgroup
		b.custom_minimum_size = Vector2(0, 34)
		b.button_pressed = (i == int(ch["look"]))
		b.pressed.connect(_on_look.bind(i))
		look_row.add_child(b)
	# colores
	_clear(color_row)
	var cgroup := ButtonGroup.new()
	for i in ClassData.COLORS.size():
		var cb := Button.new()
		cb.toggle_mode = true
		cb.button_group = cgroup
		cb.custom_minimum_size = Vector2(38, 30)
		cb.tooltip_text = ClassData.COLORS[i]["name"]
		cb.button_pressed = (i == int(ch["color"]))
		var chip: Color = ClassData.COLORS[i]["chip"]
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var s := StyleBoxFlat.new()
			s.bg_color = chip.lightened(0.15) if state.begins_with("hover") else chip
			s.set_corner_radius_all(5)
			var selected: bool = (state == "pressed" or state == "hover_pressed")
			s.set_border_width_all(3 if selected else 1)
			s.border_color = Color(1, 1, 1) if selected else Color(0, 0, 0, 0.5)
			cb.add_theme_stylebox_override(state, s)
		cb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		cb.pressed.connect(_on_color.bind(i))
		color_row.add_child(cb)
	color_name.text = "Color: %s" % ClassData.COLORS[clampi(int(ch["color"]), 0, ClassData.COLORS.size() - 1)]["name"]


func _update_stats() -> void:
	var info := ClassData.info(String(ch["class"]))
	var w := ClassData.weapon_of(ch)
	var dmg: Array = w["dmg"]
	var avg := (float(dmg[0]) + float(dmg[1])) * 0.5
	var dps := avg / float(w["cooldown"])
	_set_stat("Vida", float(info["hp"]) / 170.0, str(info["hp"]))
	_set_stat("Daño", avg / 36.0, "%d-%d" % [dmg[0], dmg[1]])
	_set_stat("Velocidad de ataque", 1.0 / float(w["cooldown"]) / 2.8, "%.1f/s" % (1.0 / float(w["cooldown"])))
	_set_stat("Alcance", minf(float(w["range"]) / 38.0, 1.0),
			("%.1f m" % float(w["range"])) + (" · distancia" if w["kind"] == "ranged" else " · melé"))
	_set_stat("Movimiento", float(info["speed"]) / 1.2, "x%.2f" % float(info["speed"]))
	stat_values["Daño"].tooltip_text = "Daño por segundo aprox.: %.0f" % dps


func _set_stat(key: String, ratio: float, text: String) -> void:
	(stat_bars[key] as ProgressBar).value = clampf(ratio, 0.0, 1.0)
	(stat_values[key] as Label).text = text


## ---------------------------------------------------------------- eventos
func _on_class(id: String) -> void:
	if String(ch["class"]) == id:
		return
	ch["class"] = id
	ch["look"] = 0
	ch["weapon"] = 0
	_fill_classes()
	_fill_options()
	_update_stats()
	_rebuild_preview()


func _on_weapon(i: int) -> void:
	ch["weapon"] = i
	weapon_desc.text = String(ClassData.weapon_of(ch)["desc"])
	_update_stats()
	_rebuild_preview()


func _on_look(i: int) -> void:
	ch["look"] = i
	_rebuild_preview()


func _on_color(i: int) -> void:
	ch["color"] = i
	color_name.text = "Color: %s" % ClassData.COLORS[i]["name"]
	_rebuild_preview(false)


func _on_random_name() -> void:
	var n: String = NAMES[randi() % NAMES.size()]
	name_edit.text = n
	ch["name"] = n


func _on_continue() -> void:
	if GameState.load_character():
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_start() -> void:
	var n := name_edit.text.strip_edges()
	ch["name"] = n if n != "" else "Aventurero"
	GameState.new_game(ch) # personaje nuevo: nivel 1, sin talentos ni objetos
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		view_yaw += event.relative.x * 0.012
		spin_time = asin(clampf(view_yaw / 0.5, -1.0, 1.0)) / 0.6


## ------------------------------------------------------------ vista previa
func _build_preview() -> void:
	pass # los nodos se crean en _build_ui(); el personaje en _rebuild_preview()


func _rebuild_preview(play_attack := true) -> void:
	if preview_root == null:
		return
	if preview_actor != null and is_instance_valid(preview_actor):
		preview_root.remove_child(preview_actor)
		preview_actor.queue_free()
	preview_actor = CharacterActor.new()
	preview_root.add_child(preview_actor)
	var actor = preview_actor
	if actor.setup_hero(ClassData.actor_options(ch)):
		actor.action_finished.connect(func(_n): actor.play("Idle_A"))
	preview_token += 1
	if play_attack:
		var token := preview_token
		get_tree().create_timer(0.6).timeout.connect(_preview_attack_if.bind(token))


func _preview_attack_if(token: int) -> void:
	if token == preview_token:
		_preview_attack()


func _preview_attack() -> void:
	if preview_actor == null or not is_instance_valid(preview_actor):
		return
	var anims = ClassData.weapon_of(ch)["attack"]
	var anim_name: String = anims if anims is String else String(anims[0])
	preview_actor.play_action("Attack_" + anim_name, 1.0)
