extends PanelContainer
## Panel de inventario (tecla I): cuadricula de objetos con cantidades.

const ItemData = preload("res://scripts/item_data.gd")
const ProgressionData = preload("res://scripts/progression_data.gd")

const COLS := 6
const SLOTS := 24

var grid: GridContainer
var header: Label


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
	title.text = "INVENTARIO"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	vb.add_child(title)
	header = Label.new()
	header.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	vb.add_child(header)
	grid = GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)
	var hint := Label.new()
	hint.text = "I o Esc para cerrar · Las herramientas se equipan solas al recolectar (E)"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	vb.add_child(hint)

	GameState.inventory_changed.connect(refresh)
	GameState.progress_changed.connect(refresh)
	refresh()


func refresh() -> void:
	header.text = "Nivel %d  ·  XP %d / %d  ·  Bajas: %d" % [
		GameState.level, GameState.xp, GameState.xp_needed(), GameState.kills]
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	var shown := 0
	for id in ItemData.ITEMS:
		var n := GameState.count(String(id))
		if n > 0 and shown < SLOTS:
			grid.add_child(_slot(String(id), n))
			shown += 1
	while shown < SLOTS:
		grid.add_child(_slot("", 0))
		shown += 1


func _slot(id: String, n: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(96, 72)
	b.focus_mode = Control.FOCUS_NONE
	var col := Color(0.14, 0.15, 0.2)
	if id != "":
		var it: Dictionary = ItemData.ITEMS[id]
		col = (it["color"] as Color).darkened(0.45)
		b.text = "%s\n%s" % [it["name"], ("x%d" % n) if it["type"] == "Recurso" else "Herramienta"]
		b.tooltip_text = "%s (%s)\n%s" % [it["name"], it["type"], it["desc"]]
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = col.lightened(0.1) if state == "hover" and id != "" else col
		s.set_corner_radius_all(5)
		s.set_border_width_all(1)
		s.border_color = Color(0.4, 0.4, 0.5, 0.6)
		b.add_theme_stylebox_override(state, s)
	return b
