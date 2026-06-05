extends SceneTree

var gallo: Node3D
var frame := 0
var shots := {30: "act_idle", 100: "act_move", 150: "act_punch", 215: "act_knocked", 360: "act_recovered"}

func _initialize() -> void:
	var world := Node3D.new(); get_root().add_child(world)
	var cam := Camera3D.new()
	cam.look_at_from_position(Vector3(4.0, 2.0, 4.5), Vector3(0.6, 0.7, -0.6), Vector3.UP)
	world.add_child(cam)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-50,-40,0); world.add_child(light)
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
	var ps: PackedScene = load("res://characters/gallo/gallo_6dof.tscn")
	gallo = ps.instantiate(); world.add_child(gallo); gallo.position = Vector3(0,0.3,0)

func _process(_d: float) -> bool:
	frame += 1
	if frame == 40: Input.action_press("move_forward", 1.0)
	if frame == 120: Input.action_release("move_forward")
	if frame == 140: print(">> punch"); gallo._punch(gallo.arm_r, false)
	if frame == 180: print(">> knockout"); gallo._knockout()
	if frame % 20 == 0:
		var t = gallo.get("torso")
		if t: print("f%d torso=(%.2f,%.2f,%.2f) up=%.2f ko=%.2f" % [frame, t.global_position.x, t.global_position.y, t.global_position.z, t.global_transform.basis.y.dot(Vector3.UP), gallo.get("_ko_timer")])
	if frame in shots:
		var img := get_root().get_texture().get_image()
		if img: img.save_png("/home/mva/Desktop/seremosmillonarios/tools/%s.png" % shots[frame])
	if frame > 365: quit()
	return false
