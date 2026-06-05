extends SceneTree

# Spawnea el gallo como jugador local SIN inputs y reporta si se desplaza.
var gallo: Node3D
var frame := 0
var start_pos: Vector3

func _initialize() -> void:
	var world := Node3D.new()
	get_root().add_child(world)
	var floor_body := StaticBody3D.new()
	var fcs := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(40, 0.4, 40)
	fcs.shape = box; fcs.transform.origin = Vector3(0, -0.2, 0)
	floor_body.add_child(fcs)
	world.add_child(floor_body)

	var ps: PackedScene = load("res://characters/gallo/gallo.tscn")
	gallo = ps.instantiate()
	gallo.is_local = true
	world.add_child(gallo)
	gallo.global_position = Vector3(0, 0.05, 0)
	start_pos = gallo.global_position

func _process(_d: float) -> bool:
	frame += 1
	if frame % 20 == 0:
		var p: Vector3 = gallo.global_position
		print("frame ", frame, " pos=", p, " delta=", (p - start_pos), " vel=", gallo.velocity, " on_floor=", gallo.is_on_floor())
	if frame > 120:
		quit()
	return false
