extends SceneTree

var gallo: Node3D
var frame := 0
var shots := {18: "move_start", 70: "move_mid", 120: "move_end", 175: "move_punch"}

func _initialize() -> void:
	var world := Node3D.new()
	get_root().add_child(world)
	var cam := Camera3D.new()
	cam.look_at_from_position(Vector3(5.0, 2.2, 5.5), Vector3(1.5, 0.7, -1.5), Vector3.UP)
	world.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-40,0); world.add_child(light)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.25,0.27,0.3)
	e.ambient_light_color = Color(0.6,0.6,0.6); e.ambient_light_energy = 1.0
	env.environment = e; world.add_child(env)
	var fb := StaticBody3D.new()
	var fcs := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(60,0.4,60)
	fcs.shape = box; fcs.transform.origin = Vector3(0,-0.2,0); fb.add_child(fcs)
	var fm := MeshInstance3D.new(); var pm := BoxMesh.new(); pm.size = Vector3(60,0.4,60)
	fm.mesh = pm; fm.transform.origin = Vector3(0,-0.2,0); fb.add_child(fm)
	world.add_child(fb)
	var ps: PackedScene = load("res://characters/gallo/gallo.tscn")
	gallo = ps.instantiate(); gallo.is_local = true
	world.add_child(gallo); gallo.global_position = Vector3(0, 0.05, 0)

func _process(_d: float) -> bool:
	frame += 1
	if frame == 20:
		Input.action_press("move_forward", 1.0)
		Input.action_press("move_right", 0.6)
	if frame == 130:
		Input.action_release("move_forward"); Input.action_release("move_right")
	if frame == 150 and gallo.get("_combat"):
		print(">> punch")
		gallo._combat.punch(gallo)
	if frame % 20 == 0:
		var t = gallo.get("_torso"); var ll = gallo.bone("leg_l"); var hd = gallo.bone("head")
		if t and ll:
			var horiz = Vector2(t.global_position.x - ll.global_position.x, t.global_position.z - ll.global_position.z).length()
			print("f%d torso=(%.2f,%.2f,%.2f) up=%.2f leg_gap=%.2f head_gap=%.2f" % [frame, t.global_position.x, t.global_position.y, t.global_position.z, t.global_transform.basis.y.dot(Vector3.UP), horiz, (hd.global_position - t.global_position).length() if hd else 0.0])
	if frame in shots:
		var img := get_root().get_texture().get_image()
		img.save_png("/home/mva/Desktop/seremosmillonarios/tools/%s.png" % shots[frame])
	if frame > 180:
		quit()
	return false
