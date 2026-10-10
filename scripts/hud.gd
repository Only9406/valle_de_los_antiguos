extends CanvasLayer
## HUD: zona, mira, panel del heroe, marco del objetivo, barra de habilidades (1-4),
## barra de experiencia, seguimiento de mision, aviso de interaccion, progreso de
## recoleccion, avisos y los paneles de inventario (I), talentos (T) y dialogo (E).

const WorldData = preload("res://scripts/world_data.gd")
const ClassData = preload("res://scripts/class_data.gd")
const QuestData = preload("res://scripts/quest_data.gd")
const ItemData = preload("res://scripts/item_data.gd")
const InventoryPanel = preload("res://scripts/inventory_panel.gd")
const TalentPanel = preload("res://scripts/talent_panel.gd")
const DialoguePanel = preload("res://scripts/dialogue_panel.gd")

var player: Node3D
var daynight
var zone_label: Label
var info_label: Label
var hero_label: Label
var current_zone := ""
var crosshair: ColorRect
var target_panel: PanelContainer
var target_name: Label
var target_bar: ProgressBar
var target_hp: Label
var cd_bar: ProgressBar
var xp_bar: ProgressBar
var quest_label: Label
var prompt_label: Label
var gather_bar: ProgressBar
var toast_box: VBoxContainer
var slot_overlay: Array = []
var slot_name: Array = []
var slot_cd: Array = []
var slot_root: Array = []
var inventory: PanelContainer
var talents: PanelContainer
var dialogue: PanelContainer


func setup(p: Node3D, dn) -> void:
	player = p
	daynight = dn


func _ready() -> void:
	GameState.ui_open = false
	zone_label = _label(38, true)
	zone_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	zone_label.offset_top = 40.0
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_label.modulate.a = 0.0

	info_label = _label(16, true)
	info_label.position = Vector2(16, 12)

	# Mira en el centro de la pantalla (los proyectiles salen hacia ella)
	crosshair = ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.8)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -3.0
	crosshair.offset_right = 3.0
	crosshair.offset_top = -3.0
	crosshair.offset_bottom = 3.0
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)

	# Panel del heroe (abajo a la izquierda)
	hero_label = _label(20, true)
	hero_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hero_label.offset_left = 16.0
	hero_label.offset_top = -120.0
	hero_label.offset_bottom = -14.0

	# Seguimiento de mision (arriba a la derecha)
	quest_label = _label(17, true)
	quest_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	quest_label.offset_left = -380.0
	quest_label.offset_right = -16.0
	quest_label.offset_top = 14.0
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Marco del objetivo (arriba al centro)
	target_panel = PanelContainer.new()
	target_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	target_panel.offset_top = 125.0
	target_panel.offset_left = -170.0
	target_panel.offset_right = 170.0
	target_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_panel.visible = false
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_panel.add_child(vb)
	target_name = Label.new()
	target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(target_name)
	target_bar = _make_bar(Color(0.85, 0.15, 0.1), Vector2(320, 18))
	vb.add_child(target_bar)
	target_hp = Label.new()
	target_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_hp.add_theme_font_size_override("font_size", 13)
	target_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(target_hp)
	add_child(target_panel)

	_build_ability_bar()

	# Barra de experiencia (abajo al centro, bajo las habilidades)
	xp_bar = _make_bar(Color(0.55, 0.35, 0.9), Vector2(300, 8))
	xp_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	xp_bar.offset_left = -150.0
	xp_bar.offset_right = 150.0
	xp_bar.offset_top = -22.0
	xp_bar.offset_bottom = -14.0
	add_child(xp_bar)

	# Recarga del ataque basico (justo sobre las habilidades)
	cd_bar = _make_bar(Color(0.95, 0.75, 0.2), Vector2(282, 6))
	cd_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	cd_bar.offset_left = -141.0
	cd_bar.offset_right = 141.0
	cd_bar.offset_top = -112.0
	cd_bar.offset_bottom = -106.0
	cd_bar.max_value = 1.0
	add_child(cd_bar)

	# Aviso de interaccion y progreso de recoleccion
	prompt_label = _label(22, true)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.offset_left = -300.0
	prompt_label.offset_right = 300.0
	prompt_label.offset_top = -170.0
	prompt_label.offset_bottom = -135.0
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	gather_bar = _make_bar(Color(0.4, 0.8, 0.35), Vector2(220, 12))
	gather_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	gather_bar.offset_left = -110.0
	gather_bar.offset_right = 110.0
	gather_bar.offset_top = 70.0
	gather_bar.offset_bottom = 82.0
	gather_bar.max_value = 1.0
	gather_bar.visible = false
	add_child(gather_bar)

	# Avisos (+XP, +Madera, mision...)
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_box.offset_left = -250.0
	toast_box.offset_right = 250.0
	toast_box.offset_top = 190.0
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)

	# Paneles
	inventory = InventoryPanel.new()
	add_child(inventory)
	talents = TalentPanel.new()
	add_child(talents)
	dialogue = DialoguePanel.new()
	add_child(dialogue)
	dialogue.closed.connect(_sync_mouse)

	GameState.message.connect(_toast)
	GameState.open_dialogue.connect(_on_open_dialogue)


func _label(size: int, outline: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	if outline:
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _make_bar(fill: Color, size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = size
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = fill
	sb_fill.set_corner_radius_all(3)
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.05, 0.05, 0.07, 0.85)
	sb_bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", sb_fill)
	bar.add_theme_stylebox_override("background", sb_bg)
	return bar


## Cuatro casillas de habilidad con tecla, nombre, y capa oscura de enfriamiento.
func _build_ability_bar() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_left = -141.0
	row.offset_right = 141.0
	row.offset_top = -100.0
	row.offset_bottom = -30.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for i in 4:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(66, 66)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.09, 0.13, 0.9)
		sb.border_color = Color(0.5, 0.42, 0.2)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		slot.add_theme_stylebox_override("panel", sb)
		row.add_child(slot)
		var area := Control.new()
		area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(area)
		var nm := Label.new()
		nm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.add_theme_font_size_override("font_size", 12)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(nm)
		var ov := ColorRect.new()
		ov.color = Color(0, 0, 0, 0.62)
		ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ov.anchor_top = 1.0
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(ov)
		var key := Label.new()
		key.text = str(i + 1)
		key.position = Vector2(4, 0)
		key.add_theme_font_size_override("font_size", 14)
		key.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(key)
		var cd := Label.new()
		cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd.add_theme_font_size_override("font_size", 20)
		cd.add_theme_constant_override("outline_size", 5)
		cd.add_theme_color_override("font_outline_color", Color.BLACK)
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(cd)
		slot_root.append(slot)
		slot_name.append(nm)
		slot_overlay.append(ov)
		slot_cd.append(cd)


## ----------------------------------------------------------------- paneles
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_I:
		_toggle(inventory)
	elif event.keycode == KEY_T:
		_toggle(talents)
	elif event.keycode == KEY_ESCAPE and GameState.ui_open:
		inventory.visible = false
		talents.visible = false
		dialogue.visible = false
		_sync_mouse()
		get_viewport().set_input_as_handled()


func _toggle(panel: Control) -> void:
	var was := panel.visible
	inventory.visible = false
	talents.visible = false
	dialogue.visible = false
	panel.visible = not was
	_sync_mouse()
	get_viewport().set_input_as_handled()


func _on_open_dialogue(npc: Dictionary) -> void:
	inventory.visible = false
	talents.visible = false
	dialogue.open(npc)
	_sync_mouse()


## Con un panel abierto el raton se libera; al cerrarlo, se captura de nuevo.
func _sync_mouse() -> void:
	GameState.ui_open = inventory.visible or talents.visible or dialogue.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if GameState.ui_open else Input.MOUSE_MODE_CAPTURED


func _toast(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(l)
	while toast_box.get_child_count() > 5:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


## ------------------------------------------------------------------ cada frame
func _process(_delta: float) -> void:
	if player == null:
		return
	var zone := WorldData.zone_at(player.global_position)
	if zone["id"] != current_zone:
		current_zone = zone["id"]
		zone_label.text = "%s\n(%s)" % [zone["name"], zone["level"]]
		zone_label.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_interval(3.0)
		tw.tween_property(zone_label, "modulate:a", 0.0, 1.5)
	var p := player.global_position
	info_label.text = "%s\nWASD mover · Shift correr · Espacio saltar · Click atacar · 1-4 habilidades · E interactuar\nI inventario · T talentos · Esc liberar ratón · F1 crear personaje\nPos: %d, %d  |  Hora: %02d:00  |  FPS: %d" % [
		WorldData.WORLD_NAME, p.x, p.z, daynight.get_hour(), Engine.get_frames_per_second()]

	var hero: Dictionary = player.hero
	var cls := ClassData.info(String(hero.get("class", "Knight")))
	var pts := ""
	if GameState.talent_points > 0:
		pts = "\n¡%d punto(s) de talento! (T)" % GameState.talent_points
	hero_label.text = "%s — %s  Nv. %d\n%s  |  Bajas: %d%s" % [
		hero.get("name", "Aventurero"), cls["name"], GameState.level, player.weapon.get("name", ""),
		GameState.kills, pts]
	cd_bar.value = player.cooldown_ratio()
	xp_bar.max_value = maxf(float(GameState.xp_needed()), 1.0)
	xp_bar.value = GameState.xp

	_update_abilities()
	_update_quest()

	prompt_label.text = player.interact_prompt if not GameState.ui_open else ""
	gather_bar.visible = player.gathering
	gather_bar.value = player.gather_progress()

	# Objetivo: se muestra unos segundos tras golpear a un enemigo
	var t = GameState.target
	var now := Time.get_ticks_msec() / 1000.0
	if t != null and is_instance_valid(t) and now - GameState.target_time < 5.0:
		target_panel.visible = true
		target_name.text = "%s  %s" % [t.display_name, t.level_text]
		target_bar.max_value = t.max_hp
		target_bar.value = t.hp
		target_hp.text = "%d / %d" % [t.hp, t.max_hp] if not t.dead else "Derrotado"
	else:
		target_panel.visible = false


func _update_abilities() -> void:
	var abs_list: Array = player.abilities
	for i in slot_root.size():
		if i >= abs_list.size():
			continue
		var ab: Dictionary = abs_list[i]
		var locked := GameState.level < int(ab["unlock"])
		(slot_name[i] as Label).text = String(ab["name"])
		(slot_root[i] as Control).modulate = Color(0.5, 0.5, 0.55) if locked else Color(1, 1, 1)
		var cd := float(player.ability_cd[i])
		var mx := maxf(float(player.ability_cd_max[i]), 0.01)
		var ov := slot_overlay[i] as ColorRect
		ov.visible = cd > 0.0
		ov.anchor_top = clampf(1.0 - cd / mx, 0.0, 1.0)
		var cdl := slot_cd[i] as Label
		if locked:
			cdl.text = "Nv %d" % int(ab["unlock"])
		elif cd > 0.0:
			cdl.text = "%.1f" % cd
		else:
			cdl.text = ""


func _update_quest() -> void:
	var lines: Array[String] = []
	for qid in QuestData.QUESTS:
		if GameState.quest_state(String(qid)) != "active":
			continue
		var q: Dictionary = QuestData.QUESTS[qid]
		lines.append("Misión: %s" % q["title"])
		for o in q["objectives"]:
			var have := mini(GameState.count(String(o["item"])), int(o["count"]))
			var mark := "[OK] " if have >= int(o["count"]) else ""
			lines.append("%s%s: %d/%d" % [mark, ItemData.item_name(String(o["item"])), have, o["count"]])
		if GameState.quest_ready(String(qid)):
			lines.append("¡Vuelve con el %s!" % q.get("giver", "Anciano Guardián"))
	quest_label.text = "\n".join(PackedStringArray(lines))
