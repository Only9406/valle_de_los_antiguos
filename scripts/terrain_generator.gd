extends Node3D

const Palette = preload("res://scripts/palette.gd")

## Terreno procedural en forma de valle: plaza plana en el centro, bosque
## alrededor y cumbres rodeando el mapa. Incluye colision (trimesh).

@export var size := 256.0
@export var cells := 128
@export var rim_height := 34.0

var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var forest_noise := FastNoiseLite.new()


func setup(world_seed: int) -> void:
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	detail.seed = world_seed + 1
	detail.frequency = 0.05
	forest_noise.seed = world_seed + 2
	forest_noise.frequency = 0.02


## Camino de los Antiguos: sale de la plaza hacia +Z con una curva suave.
func path_x(z: float) -> float:
	return sin(z * 0.04) * 8.0


func is_on_path(x: float, z: float, margin := 3.5) -> bool:
	return z > 10.0 and absf(x - path_x(z)) < margin


func get_height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var d := r / (size * 0.5)
	var bowl := smoothstep(0.28, 0.95, d)
	var h := bowl * rim_height + maxf(0.0, d - 0.95) * 80.0
	h += noise.get_noise_2d(x, z) * (2.0 + bowl * 8.0)
	h += detail.get_noise_2d(x, z) * 0.6
	var flat := 1.0 - smoothstep(20.0, 36.0, r)
	return lerpf(h, 0.0, flat)


func get_slope(x: float, z: float) -> float:
	var dx := (get_height(x + 1.0, z) - get_height(x - 1.0, z)) * 0.5
	var dz := (get_height(x, z + 1.0) - get_height(x, z - 1.0)) * 0.5
	return sqrt(dx * dx + dz * dz)


func _color_at(x: float, z: float, h: float) -> Color:
	var r := Vector2(x, z).length()
	var slope := get_slope(x, z)
	var n := detail.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5
	var c: Color = Palette.GRASS_MID.lerp(Palette.GRASS_LIGHT, n)
	if h > 22.0:
		c = c.lerp(Color(0.85, 0.88, 0.92), smoothstep(22.0, 30.0, h))
	c = c.lerp(Palette.ROCK_DARK, smoothstep(0.55, 0.95, slope))
	if r < 30.0:
		c = c.lerp(Palette.ROCK_MID, 1.0 - smoothstep(20.0, 30.0, r))
	if z > 10.0:
		var dist := absf(x - path_x(z))
		c = c.lerp(Color(0.55, 0.42, 0.28), 1.0 - smoothstep(2.0, 4.0, dist))
	return c


func build() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := size / cells
	var half := size * 0.5
	for j in range(cells + 1):
		for i in range(cells + 1):
			var x := -half + i * step
			var z := -half + j * step
			var h := get_height(x, z)
			st.set_color(_color_at(x, z, h))
			st.set_uv(Vector2(float(i), float(j)) * 0.25)
			st.add_vertex(Vector3(x, h, z))
	for j in range(cells):
		for i in range(cells):
			var a := j * (cells + 1) + i
			var b := a + 1
			var c := a + cells + 1
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	var mesh := st.commit()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true # la paleta esta muestreada en sRGB, igual que los modelos
	mat.roughness = 1.0

	var mi := MeshInstance3D.new()
	mi.name = "MallaTerreno"
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

	var body := StaticBody3D.new()
	body.name = "ColisionTerreno"
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)
