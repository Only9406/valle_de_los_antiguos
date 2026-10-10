extends RefCounted
## Paleta del KayKit Forest Pack. Los colores estan muestreados de
## forest_texture.png para que terreno y ruinas combinen con los modelos.

const FOREST_TEX := "res://assets/kaykit_forest/forest_texture.png"

const GRASS_LIGHT := Color(0.53, 0.76, 0.25)
const GRASS_MID := Color(0.33, 0.63, 0.24)
const GRASS_DARK := Color(0.12, 0.49, 0.22)
const ROCK_LIGHT := Color(0.67, 0.72, 0.75)
const ROCK_MID := Color(0.57, 0.62, 0.64)
const ROCK_DARK := Color(0.45, 0.48, 0.50)


## Material que muestrea UN punto (px, py, en pixeles) de forest_texture.png.
## Asi las ruinas usan la misma textura que los arboles y rocas.
## Si la textura no esta, usa `fallback` como color plano.
static func swatch(px: float, py: float, fallback: Color, roughness := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = roughness
	if ResourceLoader.exists(FOREST_TEX):
		m.albedo_texture = load(FOREST_TEX)
		m.uv1_scale = Vector3(0.001, 0.001, 1.0)
		m.uv1_offset = Vector3((px + 0.5) / 1024.0, (py + 0.5) / 1024.0, 0.0)
	else:
		m.albedo_color = fallback
	return m
