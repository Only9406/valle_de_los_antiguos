extends Node3D
## Visual de un personaje KayKit (heroes Adventurers y enemigos Skeletons): carga el
## modelo .glb, aplica las animaciones del rig Rig_Medium, construye las animaciones
## de ataque, monta armas en las manos y aplica color de prenda.
##
## Heroe:   actor.setup_hero(ClassData.actor_options(personaje))
## Esqueleto: actor.setup("Warrior", Color(1, 0.2, 0.1))

signal action_finished(anim_name: String)

const SKEL := "res://assets/kaykit_skeletons"
const ADV := "res://assets/kaykit_adventurers"
const AttackData = preload("res://scripts/attack_data.gd")
const ToolModels = preload("res://scripts/tool_models.gd")

const ANIM_FILES := [
	SKEL + "/animations/Rig_Medium_General.glb",
	SKEL + "/animations/Rig_Medium_MovementBasic.glb",
]
## Animaciones que se repiten en bucle. El resto (Hit, Death, ataques...) se reproduce una vez.
const LOOPING := [
	"Idle_A", "Idle_B", "Walking_A", "Walking_B", "Walking_C",
	"Running_A", "Running_B", "Jump_Idle",
]
## Armas por defecto de los esqueletos enemigos (assets/kaykit_skeletons/props).
const SKELETON_LOADOUTS := {
	"Warrior": {"right": "Skeleton_Axe", "left": "Skeleton_Shield_Large_A"},
	"Minion": {"right": "Skeleton_Blade", "left": "Skeleton_Shield_Small_A"},
	"Rogue": {"right": "Skeleton_Crossbow"},
	"Mage": {"right": "Skeleton_Staff"},
}
## Cambia el tono de una prenda sin tocar su brillo/saturacion (salvo los multiplicadores).
const HUE_SHADER := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float target_hue = -1.0;
uniform float sat_mul = 1.0;
uniform float val_mul = 1.0;
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
void fragment() {
	vec4 t = texture(albedo_tex, UV);
	vec3 h = rgb2hsv(t.rgb);
	if (target_hue >= 0.0 && h.y > 0.12) {
		h.x = target_hue;
	}
	h.y = clamp(h.y * sat_mul, 0.0, 1.0);
	h.z = h.z * val_mul;
	ALBEDO = hsv2rgb(h);
	ROUGHNESS = 0.8;
}
"""

## Libreria de animaciones compartida por todos los personajes (se construye una vez).
static var _library: AnimationLibrary
static var _hue_shader: Shader

var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var current := ""
var _pending := ""
var _random_phase := false
var _tool_att: BoneAttachment3D


## ---------------------------------------------------------------- heroes
## opts: model, hide[], tint[], hue, sat, val, right, left (ver ClassData.actor_options)
func setup_hero(opts: Dictionary) -> bool:
	var path := "%s/characters/%s.glb" % [ADV, String(opts.get("model", "Knight"))]
	if not _load_model(path):
		return false
	_hide_parts(opts.get("hide", []))
	_apply_color(opts.get("tint", []), float(opts.get("hue", -1.0)),
			float(opts.get("sat", 1.0)), float(opts.get("val", 1.0)))
	_setup_animations()
	var right := String(opts.get("right", ""))
	var left := String(opts.get("left", ""))
	if right != "":
		_attach(right, "r", ADV + "/props/")
	if left != "":
		_attach(left, "l", ADV + "/props/")
	play("Idle_A")
	return true


## ------------------------------------------------------------- esqueletos
## kind: "Warrior", "Minion", "Rogue" o "Mage". glow: color de los ojos.
func setup(kind: String, glow := Color(1.0, 0.3, 0.15), loadout := {}) -> bool:
	var path := "%s/characters/Skeleton_%s.glb" % [SKEL, kind]
	if not _load_model(path):
		return false
	_tint_eyes(model, glow)
	_setup_animations()
	var weapons: Dictionary = loadout if not loadout.is_empty() else SKELETON_LOADOUTS.get(kind, {})
	if weapons.has("right"):
		_attach(String(weapons["right"]), "r", SKEL + "/props/")
	if weapons.has("left"):
		_attach(String(weapons["left"]), "l", SKEL + "/props/")
	play("Idle_A")
	return true


func _load_model(path: String) -> bool:
	if not ResourceLoader.exists(path):
		push_warning("[Valle] Falta el modelo " + path)
		return false
	var scn := load(path) as PackedScene
	if scn == null:
		return false
	model = scn.instantiate() as Node3D
	# Los modelos glTF miran hacia +Z; el juego usa -Z como "adelante".
	model.rotation.y = PI
	add_child(model)
	skeleton = _find_skeleton(model)
	return true


func _ready() -> void:
	# Si setup() se llamo antes de entrar al arbol, arranca ahora la animacion.
	if _pending != "":
		var p := _pending
		_pending = ""
		current = ""
		play(p)
		if _random_phase:
			randomize_phase()


## ------------------------------------------------------------ animaciones
func play(anim_name: String, blend := 0.2) -> void:
	if anim == null or current == anim_name:
		return
	if not anim.has_animation(anim_name):
		return
	current = anim_name
	if not is_inside_tree():
		_pending = anim_name
		return
	anim.play(anim_name, blend)


## Reproduce una animacion de accion (ataque, golpe, muerte...) a la velocidad dada.
## Devuelve su duracion real en segundos (0 si no existe).
func play_action(anim_name: String, speed := 1.0) -> float:
	if anim == null or not anim.has_animation(anim_name):
		return 0.0
	current = anim_name
	if is_inside_tree():
		anim.play(anim_name, 0.08, speed)
	return anim.get_animation(anim_name).length / speed


func has_anim(anim_name: String) -> bool:
	return anim != null and anim.has_animation(anim_name)


## Desincroniza la animacion actual (para que varios personajes no vayan al unisono).
func randomize_phase() -> void:
	if not is_inside_tree():
		_random_phase = true # se aplica en _ready, cuando ya este en el arbol
		return
	_random_phase = false
	if anim != null and anim.current_animation != "":
		anim.seek(randf() * anim.current_animation_length, true)


## Posicion global de la mano ("r" o "l"); sirve para lanzar proyectiles desde ella.
func hand_position(side: String) -> Vector3:
	if skeleton != null:
		var idx := _hand_bone(side)
		if idx >= 0:
			return skeleton.to_global(skeleton.get_bone_global_pose(idx).origin)
	return global_position + Vector3(0, 1.3, 0)


## Pone una herramienta de recoleccion ("axe", "pickaxe", "sickle") en la mano derecha
## y oculta temporalmente el arma. hide_tool() la quita y devuelve el arma.
func show_tool(tool_id: String) -> void:
	hide_tool()
	if skeleton == null or tool_id == "":
		return
	var idx := _hand_bone("r")
	if idx < 0:
		return
	_tool_att = BoneAttachment3D.new()
	_tool_att.name = "Herramienta"
	skeleton.add_child(_tool_att)
	_tool_att.bone_name = skeleton.get_bone_name(idx)
	var holder := Node3D.new()
	# misma orientacion que una espada de una mano
	var m: Array = AttackData.MOUNTS["sword_1handed"]["r"]
	holder.quaternion = Quaternion(m[0], m[1], m[2], m[3])
	_tool_att.add_child(holder)
	holder.add_child(ToolModels.build(tool_id))
	var weapon := skeleton.get_node_or_null("Arma_R")
	if weapon != null:
		(weapon as Node3D).visible = false


func hide_tool() -> void:
	if _tool_att != null and is_instance_valid(_tool_att):
		_tool_att.queue_free()
	_tool_att = null
	if skeleton != null:
		var weapon := skeleton.get_node_or_null("Arma_R")
		if weapon != null:
			(weapon as Node3D).visible = true


func _on_anim_finished(anim_name: StringName) -> void:
	current = ""
	action_finished.emit(String(anim_name))


func _setup_animations() -> void:
	anim = AnimationPlayer.new()
	anim.name = "Animaciones"
	model.add_child(anim)
	# Las pistas de los .glb de animacion apuntan a "Skeleton3D:hueso" desde la raiz del modelo.
	anim.root_node = NodePath("..")
	anim.add_animation_library("", _get_library(model, skeleton))
	anim.animation_finished.connect(_on_anim_finished)


static func _get_library(root: Node, skel: Skeleton3D) -> AnimationLibrary:
	if _library != null:
		return _library
	_library = AnimationLibrary.new()
	for path in ANIM_FILES:
		if not ResourceLoader.exists(path):
			push_warning("[Valle] Falta el archivo de animaciones " + path)
			continue
		var scn := load(path) as PackedScene
		if scn == null:
			continue
		var inst := scn.instantiate()
		for n in inst.find_children("*", "AnimationPlayer", true, false):
			var ap := n as AnimationPlayer
			for full in ap.get_animation_list():
				var short := String(full).get_file()
				if short == "RESET" or _library.has_animation(short):
					continue
				var a := ap.get_animation(full).duplicate() as Animation
				a.loop_mode = Animation.LOOP_LINEAR if short in LOOPING else Animation.LOOP_NONE
				_library.add_animation(short, a)
		inst.free()
	if skel != null and _library.has_animation("Idle_A"):
		_build_attacks(_library, root, skel)
	print("[Valle] Animaciones cargadas: ", _library.get_animation_list().size())
	return _library


## Crea las animaciones "Attack_*" a partir de Idle_A, sustituyendo las pistas del torso y
## los brazos por las generadas con IK (attack_data.gd). Las piernas siguen el idle.
static func _build_attacks(lib: AnimationLibrary, root: Node, skel: Skeleton3D) -> void:
	var bones := {} # nombre normalizado -> nombre real del hueso
	for i in skel.get_bone_count():
		bones[_norm(skel.get_bone_name(i))] = skel.get_bone_name(i)
	var prefix := _track_prefix(lib, root, skel)
	var used: Array = []
	for nm in AttackData.ATTACKS:
		for pybone in AttackData.ATTACKS[nm]["tracks"]:
			var real: String = bones.get(_norm(String(pybone)), "")
			if real != "" and not used.has(real):
				used.append(real)
	# Todas las animaciones deben tener pistas de esos huesos para volver bien del ataque.
	for an in lib.get_animation_list():
		_ensure_rotation_tracks(lib.get_animation(an), prefix, used, skel)
	var base := lib.get_animation("Idle_A")
	for nm in AttackData.ATTACKS:
		var d: Dictionary = AttackData.ATTACKS[nm]
		var a := base.duplicate() as Animation
		a.loop_mode = Animation.LOOP_NONE
		a.length = float(d["length"])
		var tracks: Dictionary = d["tracks"]
		for pybone in tracks:
			var real: String = bones.get(_norm(String(pybone)), "")
			if real == "":
				continue
			_remove_rotation_track(a, real)
			var ti := a.add_track(Animation.TYPE_ROTATION_3D)
			a.track_set_path(ti, NodePath("%s:%s" % [prefix, real]))
			a.track_set_interpolation_type(ti, Animation.INTERPOLATION_LINEAR)
			var arr: Array = tracks[pybone]
			for k in range(0, arr.size(), 5):
				a.rotation_track_insert_key(ti, float(arr[k]),
						Quaternion(arr[k + 1], arr[k + 2], arr[k + 3], arr[k + 4]))
		lib.add_animation("Attack_" + String(nm), a)


static func _norm(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out


## Ruta del nodo Skeleton3D tal y como la usan las pistas importadas (p. ej. "Skeleton3D").
static func _track_prefix(lib: AnimationLibrary, root: Node, skel: Skeleton3D) -> String:
	var a := lib.get_animation("Idle_A")
	for i in a.get_track_count():
		var p := String(a.track_get_path(i))
		if p.contains(":"):
			return p.get_slice(":", 0)
	var parts: Array = []
	var n: Node = skel
	while n != null and n != root:
		parts.push_front(String(n.name))
		n = n.get_parent()
	return "/".join(parts)


static func _track_bone(a: Animation, i: int) -> String:
	var p := String(a.track_get_path(i))
	if not p.contains(":"):
		return ""
	return _norm(p.get_slice(":", p.get_slice_count(":") - 1))


static func _remove_rotation_track(a: Animation, bone: String) -> void:
	var want := _norm(bone)
	for i in range(a.get_track_count() - 1, -1, -1):
		if a.track_get_type(i) == Animation.TYPE_ROTATION_3D and _track_bone(a, i) == want:
			a.remove_track(i)


static func _ensure_rotation_tracks(a: Animation, prefix: String, bone_names: Array, skel: Skeleton3D) -> void:
	var have := {}
	for i in a.get_track_count():
		if a.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			have[_track_bone(a, i)] = true
	for b in bone_names:
		if have.has(_norm(String(b))):
			continue
		var idx := skel.find_bone(String(b))
		if idx < 0:
			continue
		var ti := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(ti, NodePath("%s:%s" % [prefix, String(b)]))
		a.rotation_track_insert_key(ti, 0.0, skel.get_bone_rest(idx).basis.get_rotation_quaternion())


## ----------------------------------------------------------- aspecto/armas
func _find_skeleton(root: Node) -> Skeleton3D:
	var found := root.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return null
	return found[0] as Skeleton3D


func _hide_parts(parts: Array) -> void:
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var low := String(n.name).to_lower()
		for p in parts:
			if low.contains(String(p).to_lower()):
				(n as MeshInstance3D).visible = false


func _apply_color(parts: Array, hue: float, sat: float, val: float) -> void:
	if hue < 0.0 and is_equal_approx(sat, 1.0) and is_equal_approx(val, 1.0):
		return
	if _hue_shader == null:
		_hue_shader = Shader.new()
		_hue_shader.code = HUE_SHADER
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var low := String(mi.name).to_lower()
		var matches := false
		for p in parts:
			if low.contains(String(p).to_lower()):
				matches = true
		if not matches:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if m == null or m.albedo_texture == null:
				continue
			var sm := ShaderMaterial.new()
			sm.shader = _hue_shader
			sm.set_shader_parameter("albedo_tex", m.albedo_texture)
			sm.set_shader_parameter("target_hue", hue)
			sm.set_shader_parameter("sat_mul", sat)
			sm.set_shader_parameter("val_mul", val)
			mi.set_surface_override_material(s, sm)


func _tint_eyes(root: Node, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.4)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var is_eyes := String(mi.name).to_lower().contains("eyes")
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if is_eyes or (m != null and m.resource_name.to_lower() == "glow"):
				mi.set_surface_override_material(s, mat)


func _attach(prop_name: String, side: String, dir: String) -> void:
	if skeleton == null:
		return
	var path := "%s%s.gltf" % [dir, prop_name]
	if not ResourceLoader.exists(path):
		push_warning("[Valle] Falta el arma " + path)
		return
	var idx := _hand_bone(side)
	if idx < 0:
		return
	var att := BoneAttachment3D.new()
	att.name = "Arma_" + side.to_upper()
	skeleton.add_child(att)
	att.bone_name = skeleton.get_bone_name(idx)
	var holder := Node3D.new()
	# Orientacion de reposo del arma en la mano (calculada con el rig; ver attack_data.gd)
	if AttackData.MOUNTS.has(prop_name):
		var m: Array = AttackData.MOUNTS[prop_name][side]
		holder.quaternion = Quaternion(m[0], m[1], m[2], m[3])
		holder.position = Vector3(m[4], m[5], m[6])
	att.add_child(holder)
	holder.add_child((load(path) as PackedScene).instantiate())


## Busca el hueso "handslot.r" / "handslot.l" (donde KayKit sujeta las armas).
func _hand_bone(side: String) -> int:
	if skeleton == null:
		return -1
	for i in skeleton.get_bone_count():
		var n := skeleton.get_bone_name(i).to_lower()
		if n.begins_with("handslot") and n.ends_with(side):
			return i
	return -1
