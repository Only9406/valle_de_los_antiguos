extends RefCounted
## Escanea res://assets/kaykit_forest y clasifica los modelos por nombre
## (Tree_*, Tree_Bare_* = arbol muerto, Rock_*, Bush_*, Grass_*). Funciona en editor y en exportado.

const ROOT := "res://assets/kaykit_forest"
const SKIP_WORDS := ["cloud", "hill", "mountain"]

var scenes := {"tree": [], "deadtree": [], "rock": [], "bush": [], "grass": []}
var total := 0


func scan(preferred_variant := "Color1") -> void:
	var files: Array[String] = []
	_walk(ROOT, files)
	# Para no mezclar todas las paletas de color, se usa una sola variante si existe.
	var chosen: Array[String] = []
	for f in files:
		if preferred_variant.to_lower() in f.get_file().to_lower():
			chosen.append(f)
	if chosen.is_empty():
		chosen = files
	for f in chosen:
		var n := f.get_file().to_lower()
		var skip := false
		for w in SKIP_WORDS:
			if w in n:
				skip = true
		if skip:
			continue
		var cat := ""
		if "tree_bare" in n:
			cat = "deadtree"
		elif "tree" in n:
			cat = "tree"
		elif "rock" in n:
			cat = "rock"
		elif "bush" in n:
			cat = "bush"
		elif "grass" in n:
			cat = "grass"
		if cat == "":
			continue
		var res := load(f)
		if res is PackedScene:
			scenes[cat].append(res)
			total += 1


func _walk(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if dir.current_is_dir():
			if not n.begins_with("."):
				_walk(path + "/" + n, out)
		else:
			var fn := n
			if fn.ends_with(".import"):
				fn = fn.trim_suffix(".import")
			if fn.ends_with(".remap"):
				fn = fn.trim_suffix(".remap")
			var ext := fn.get_extension().to_lower()
			if ext == "gltf" or ext == "glb":
				var full := path + "/" + fn
				if not out.has(full):
					out.append(full)
		n = dir.get_next()
	dir.list_dir_end()
