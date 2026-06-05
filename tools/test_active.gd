extends SceneTree

var gallo: Node3D
var frame := 0
var shots := {40: "active_stand", 95: "active_knocked", 480: "active_recovered"}

func _initialize() -> void:
	var world := Node3D.new()
	get_root().add_child(world)
	var cam := Camera3D.new()
	cam.look_at_from_position(Vector3(3.0, 1.6, 3.6), Vector3(0, 0.9, 0), Vector3.UP)
	world.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -40, 0); world.add_child(light)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.25,0.27,0.3)
	e.ambient_light_color = Color(0.6,0.6,0.6); e.ambient_light_energy = 1.0
	env.environment = e; world.add_child(env)

	var fb := StaticBody3D.new()
	var fcs := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(40,0.4,40)
	fcs.shape = box; fcs.transform.origin = Vector3(0,-0.2,0); fb.add_child(fcs)
	var fm := MeshInstance3D.new(); var pm := BoxMesh.new(); pm.size = Vector3(40,0.4,40)
	fm.mesh = pm; fm.transform.origin = Vector3(0,-0.2,0); fb.add_child(fm)
	world.add_child(fb)

	var ps: PackedScene = load("res://characters/gallo/gallo.tscn")
	gallo = ps.instantiate()
	gallo.is_local = true
	world.add_child(gallo)
	gallo.global_position = Vector3(0, 0.05, 0)

func _process(_d: float) -> bool:
	frame += 1
	if frame == 60 and gallo.has_method("knock_down"):
		print(">> knock_down (golpe lateral)")
		gallo.knock_down(Vector3(7, 3, 0))
	if frame % 20 == 0:
		var t = gallo.get("_torso")
		if t:
			var up_dot = t.global_transform.basis.y.dot(Vector3.UP)
			print("f", frame, " torso_y=%.2f up=%.2f stun=%.2f ragdoll=%s" % [t.global_position.y, up_dot, gallo.get("_stun"), gallo.is_ragdoll])
	if frame in shots:
		var img := get_root().get_texture().get_image()
		img.save_png("/home/mva/Desktop/seremosmillonarios/tools/%s.png" % shots[frame])
		print("shot ", shots[frame])
	if frame > 485:
		quit()
	return false
