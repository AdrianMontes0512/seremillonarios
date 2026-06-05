extends SceneTree

# Prueba local del ragdoll del gallo (sin red). Renderiza, dispara ragdoll
# y guarda screenshots para verificar el desplome y que la malla siga huesos.

var gallo: Node3D
var frame := 0
var shots := {10: "stand", 45: "fall_mid", 95: "fall_end"}

func _initialize() -> void:
	var world := Node3D.new()
	get_root().add_child(world)

	# Camara
	var cam := Camera3D.new()
	cam.transform.origin = Vector3(2.5, 1.6, 3.2)
	cam.look_at_from_position(Vector3(2.5, 1.6, 3.2), Vector3(0, 0.9, 0), Vector3.UP)
	world.add_child(cam)

	# Luz
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -40, 0)
	world.add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.25, 0.27, 0.3); e.ambient_light_color = Color(0.6,0.6,0.6)
	e.ambient_light_energy = 1.0; env.environment = e
	world.add_child(env)

	# Piso
	var floor_body := StaticBody3D.new()
	var fcs := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(20, 0.4, 20)
	fcs.shape = box; fcs.transform.origin = Vector3(0, -0.2, 0)
	floor_body.add_child(fcs)
	var fmesh := MeshInstance3D.new()
	var pm := BoxMesh.new(); pm.size = Vector3(20, 0.4, 20)
	fmesh.mesh = pm; fmesh.transform.origin = Vector3(0, -0.2, 0)
	floor_body.add_child(fmesh)
	world.add_child(floor_body)

	# Gallo
	var ps: PackedScene = load("res://characters/gallo/gallo.tscn")
	gallo = ps.instantiate()
	gallo.is_local = false
	world.add_child(gallo)
	gallo.global_position = Vector3(0, 0.05, 0)
	print("Gallo cargado. Hijos: ", gallo.get_children().map(func(c): return c.name))

func _process(_d: float) -> bool:
	frame += 1
	if frame == 12:
		# Disparar ragdoll con un empujón lateral
		print(">> enter_ragdoll")
		gallo.enter_ragdoll(Vector3(6, 4, 2), gallo.global_position + Vector3(0, 1.0, 0))
	if frame in shots:
		var img := get_root().get_texture().get_image()
		var path := "/home/mva/Desktop/seremosmillonarios/tools/ragdoll_%s.png" % shots[frame]
		img.save_png(path)
		print("screenshot ", path)
	if frame > 100:
		quit()
	return false
