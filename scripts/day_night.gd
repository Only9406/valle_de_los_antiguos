extends Node
## Ciclo dia/noche simple. t = 0.25 es mediodia, 0.75 medianoche.

@export var day_length := 600.0 # segundos reales por dia completo

var t := 0.32
var sun: DirectionalLight3D
var env: Environment
var sky: ProceduralSkyMaterial


func setup(s: DirectionalLight3D, e: Environment, sk: ProceduralSkyMaterial) -> void:
	sun = s
	env = e
	sky = sk
	_apply()


func get_hour() -> int:
	return int(fposmod((t - 0.25) * 24.0 + 12.0, 24.0))


func _process(delta: float) -> void:
	t = fmod(t + delta / day_length, 1.0)
	_apply()


func _apply() -> void:
	var elev := sin(t * TAU)
	sun.rotation = Vector3(-t * TAU, deg_to_rad(-35.0), 0.0)
	var day := smoothstep(-0.05, 0.35, elev)
	sun.visible = day > 0.01
	sun.light_energy = lerpf(0.0, 1.3, day)
	sun.light_color = Color(1.0, 0.75, 0.5).lerp(Color(1.0, 0.97, 0.9), smoothstep(0.0, 0.5, elev))

	var top := Color(0.02, 0.03, 0.08).lerp(Color(0.30, 0.52, 0.85), day)
	var hor := Color(0.05, 0.06, 0.12).lerp(Color(0.70, 0.82, 0.92), day)
	var dusk := (1.0 - smoothstep(0.0, 0.4, absf(elev))) * day
	hor = hor.lerp(Color(0.95, 0.55, 0.3), dusk * 0.7)
	sky.sky_top_color = top
	sky.sky_horizon_color = hor
	sky.ground_horizon_color = hor
	sky.ground_bottom_color = top.darkened(0.5)
	env.fog_light_color = hor
	env.ambient_light_energy = lerpf(0.35, 1.0, day)
