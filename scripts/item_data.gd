extends RefCounted
## Objetos del inventario y nodos recolectables (arboles, rocas, hierbas).

const ITEMS := {
	"wood": {"name": "Madera", "type": "Recurso", "color": Color(0.55, 0.36, 0.2),
		"desc": "Troncos cortados con el hacha."},
	"stone": {"name": "Piedra", "type": "Recurso", "color": Color(0.58, 0.62, 0.68),
		"desc": "Fragmentos de roca extraídos con el pico."},
	"herb": {"name": "Hierba", "type": "Recurso", "color": Color(0.3, 0.7, 0.3),
		"desc": "Hierbas silvestres cortadas con la hoz."},
	"axe": {"name": "Hacha de leñador", "type": "Herramienta", "color": Color(0.85, 0.55, 0.2),
		"desc": "Sirve para cortar árboles. Se equipa sola al recolectar."},
	"pickaxe": {"name": "Pico de minero", "type": "Herramienta", "color": Color(0.7, 0.72, 0.78),
		"desc": "Sirve para picar rocas. Se equipa sola al recolectar."},
	"sickle": {"name": "Hoz", "type": "Herramienta", "color": Color(0.8, 0.8, 0.45),
		"desc": "Sirve para cortar hierbas. Se equipa sola al recolectar."},
}

## Tipos de nodo recolectable: herramienta necesaria, botin por carga, cargas, tiempo (s)
## por recoleccion y tiempo de reaparicion (s).
const GATHER := {
	"wood": {"tool": "axe", "label": "Cortar árbol", "yield": [2, 3], "charges": 3,
		"time": 1.7, "respawn": 120.0, "chip": Color(0.6, 0.4, 0.2)},
	"stone": {"tool": "pickaxe", "label": "Picar roca", "yield": [2, 3], "charges": 3,
		"time": 1.9, "respawn": 120.0, "chip": Color(0.7, 0.72, 0.78)},
	"herb": {"tool": "sickle", "label": "Cortar hierba", "yield": [1, 2], "charges": 1,
		"time": 1.0, "respawn": 60.0, "chip": Color(0.4, 0.8, 0.3)},
}


static func item_name(id: String) -> String:
	if ITEMS.has(id):
		return String(ITEMS[id]["name"])
	return id
