extends PanelContainer
## Dialogo con un NPC: misiones (aceptar / entregar) y frases sueltas.

const QuestData = preload("res://scripts/quest_data.gd")
const ItemData = preload("res://scripts/item_data.gd")

signal closed

var npc := {}
var name_label: Label
var text_label: Label
var buttons_box: HBoxContainer


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -150.0
	custom_minimum_size = Vector2(680, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.13, 0.97)
	sb.set_content_margin_all(16)
	sb.border_color = Color(0.45, 0.38, 0.18)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	vb.add_child(name_label)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(640, 0)
	vb.add_child(text_label)
	buttons_box = HBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 10)
	vb.add_child(buttons_box)


func open(n: Dictionary) -> void:
	npc = n
	visible = true
	_refresh()


func close() -> void:
	visible = false
	closed.emit()


func _add_button(label: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 36)
	b.pressed.connect(cb)
	buttons_box.add_child(b)


func _objectives_text(q: Dictionary) -> String:
	var lines: Array[String] = []
	for o in q["objectives"]:
		var have := mini(GameState.count(String(o["item"])), int(o["count"]))
		lines.append("• %s: %d / %d" % [ItemData.item_name(String(o["item"])), have, o["count"]])
	return "\n".join(PackedStringArray(lines))


func _refresh() -> void:
	for c in buttons_box.get_children():
		buttons_box.remove_child(c)
		c.queue_free()
	name_label.text = "%s — %s" % [npc.get("name", ""), npc.get("title", "")]
	var qid := String(npc.get("quest", ""))
	if qid != "":
		var q: Dictionary = QuestData.QUESTS[qid]
		var st := GameState.quest_state(qid)
		if st == "":
			text_label.text = "%s\n\nMisión: %s\n%s\nRecompensa: %d XP y %d punto de talento." % [
				q["intro"], q["title"], _objectives_text(q), q["reward_xp"], q["reward_points"]]
			_add_button("Aceptar misión", _on_accept.bind(qid))
		elif st == "active":
			if GameState.quest_ready(qid):
				text_label.text = "%s\n\n%s" % [q["ready"], _objectives_text(q)]
				_add_button("Entregar misión", _on_turn_in.bind(qid))
			else:
				text_label.text = "%s\n\n%s" % [q["progress"], _objectives_text(q)]
		else:
			text_label.text = String(q["done"])
	else:
		var lines: Array = QuestData.LINES.get(String(npc.get("id", "")), ["Que los Antiguos te guíen."])
		text_label.text = String(lines[randi() % lines.size()])
	_add_button("Cerrar", close)


func _on_accept(qid: String) -> void:
	GameState.start_quest(qid)
	_refresh()


func _on_turn_in(qid: String) -> void:
	GameState.complete_quest(qid)
	_refresh()
