extends SceneTree

# Valida LOCALMENTE la sync de red 6DOF (sin Steam): un "host" (authority, simula)
# y un "client" (no authority, cuerpos congelados) que recibe el estado del host
# y debe MIRRORearlo.

var host: Node3D
var client: Node3D
var frame := 0

func _initialize() -> void:
	var world := Node3D.new(); get_root().add_child(world)
	var cam := Camera3D.new()
	cam.look_at_from_position(Vector3(0, 2.4, 5.5), Vector3(0, 0.9, 0), Vector3.UP)
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
	host = ps.instantiate(); world.add_child(host); host.position = Vector3(-1.2, 0.3, 0)
	host.setup_net(true, 1, true)        # authority: simula
	client = ps.instantiate(); world.add_child(client); client.position = Vector3(1.2, 0.3, 0)
	client.setup_net(false, 1, false)    # NO authority: congelado, solo muestra

func _process(_d: float) -> bool:
	frame += 1
	# Replicar estado host -> client cada frame (como haría la red).
	if host and client:
		client.apply_net_state(host.get_net_state())
	if frame == 40 and host:
		host.torso.apply_central_impulse(Vector3(3, 0, 2))   # tambalear al host
	if frame % 20 == 0 and host and client:
		var ht = host.torso.global_position
		var ct = client.torso.global_position
		# Comparar la FORMA (posición relativa al torso de cada uno) no la absoluta,
		# porque están separados 2.4 en X. Medimos la cabeza relativa al torso.
		var hrel = host.head.global_position - ht
		var crel = client.head.global_position - ct
		print("f%d host_torso_up=%.2f  head_rel_diff=%.3f" % [frame, host.torso.global_transform.basis.y.dot(Vector3.UP), (hrel - crel).length()])
	if frame in {30: 1, 90: 1}:
		var img = get_root().get_texture().get_image()
		if img: img.save_png("/home/mva/Desktop/seremosmillonarios/tools/net6_t%d.png" % (0 if frame == 30 else 1))
	if frame > 120:
		quit()
	return false
