extends PanelContainer
## Panel de talentos (tecla T): tres ramas con tres filas; cada fila se desbloquea al
## gastar puntos en su rama. Muestra tambien las habilidades de tu clase.

const ProgressionData = preload("res://scripts/progression_data.gd")

var points_label: Label
var ability_label: Label
var buttons := {}


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.15, 0.97)
	sb.set_content_margin_all(16)
	sb.border_color = Color(0.45, 0.38, 0.18)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)
	var title := Label.new()
	title.text = "TALENTOS"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	vb.add_child(title)
	points_label = Label.new()
	vb.add_child(points_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	for b in ProgressionData.BRANCHES.size():
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		row.add_child(col)
		var bl := Label.new()
		bl.text = String(ProgressionData.BRANCHES[b]["name"]).to_upper()
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.add_theme_color_override("font_color", ProgressionData.BRANCHES[b]["color"])
		col.add_child(bl)
		for tier in 3:
			var id := _talent_at(b, tier)
			if id == "":
				continue
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(190, 66)
			btn.focus_mode = Control.FOCUS_NONE
			btn.pressed.connect(_on_pressed.bind(id))
			col.add_child(btn)
			buttons[id] = btn

	vb.add_child(HSeparator.new())
	var al := Label.new()
	al.text = "HABILIDADES (teclas 1-4)"
	al.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	vb.add_child(al)
	ability_label = Label.new()
	ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability_label.custom_minimum_size = Vector2(620, 0)
	ability_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	vb.add_child(ability_label)

	var reset := Button.new()
	reset.text = "Reiniciar talentos"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(GameState.reset_talents)
	vb.add_child(reset)
	var hint := Label.new()
	hint.text = "T o Esc para cerrar · Ganas 1 punto por nivel"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	vb.add_child(hint)

	GameState.progress_changed.connect(refresh)
	refresh()


func _talent_at(branch: int, tier: int) -> String:
	for id in ProgressionData.TALENTS:
		var t: Dictionary = ProgressionData.TALENTS[id]
		if int(t["branch"]) == branch and int(t["tier"]) == tier:
			return String(id)
	return ""


func _on_pressed(id: String) -> void:
	GameState.spend_talent(id)


func refresh() -> void:
	points_label.text = "Puntos disponibles: %d   (nivel %d)" % [GameState.talent_points, GameState.level]
	for id in buttons:
		var t: Dictionary = ProgressionData.TALENTS[id]
		var btn: Button = buttons[id]
		var rank := GameState.talent_rank(String(id))
		btn.text = "%s\n%d / %d" % [t["name"], rank, t["max"]]
		var need: int = ProgressionData.TIER_REQ[int(t["tier"])]
		var have := GameState.points_in_branch(int(t["branch"]))
		var tip := String(t["desc"])
		if need > have:
			tip += "\nRequiere %d puntos en la rama (tienes %d)." % [need, have]
		btn.tooltip_text = tip
		btn.modulate = Color(1, 1, 1) if (GameState.can_spend(String(id)) or rank > 0) else Color(0.6, 0.6, 0.65)
	var cls := String(GameState.get_character().get("class", "Knight"))
	var lines: Array[String] = []
	var abilities: Array = ProgressionData.abilities_of(cls)
	for i in abilities.size():
		var ab: Dictionary = abilities[i]
		lines.append("%d · %s (nivel %d, %.0f s): %s" % [i + 1, ab["name"], ab["unlock"], ab["cd"], ab["desc"]])
	ability_label.text = "\n".join(PackedStringArray(lines))
