extends SceneTree

# Genera characters/gallo/gallo.tscn con la estructura para ragdoll:
#   Gallo (CharacterBody3D) [gallo.gd]
#   ├── CollisionShape3D (capsula, caminar)
#   └── Skeleton3D (hijo directo) -> MeshInstance "gallo" + 6 PhysicalBone3D
#
# Replica "Create Physical Skeleton": una capsula por hueso, joint PIN al padre.

# Colas de hueso en coords Godot (Y-up), desde el rig de Blender
const TAILS := {
	"torso": Vector3(0, 1.35, 0),
	"head":  Vector3(0, 1.68, 0),
	"arm_l": Vector3(0.42, 0.95, 0),
	"arm_r": Vector3(-0.42, 0.95, 0),
	"leg_l": Vector3(0.11, 0, 0),
	"leg_r": Vector3(-0.11, 0, 0),
}
# Masa por hueso (centro de masa bajo: torso/piernas pesados)
const MASSES := {
	"torso": 3.0, "head": 1.0, "arm_l": 0.5, "arm_r": 0.5, "leg_l": 1.5, "leg_r": 1.5,
}

# Limites del joint CONE por hueso, en GRADOS (en Godot 4.6 swing_span/twist_span
# se expresan en grados, igual que el inspector: defaults 45/180).
#   swing = apertura del cono (que tanto puede inclinarse el hueso)
#   twist = giro sobre su propio eje
# Feel del gallo: el mas ESTABLE.
#   head -> casi rigido; leg_* -> estables, no se abren; arm_* -> moderados.
const CONE_LIMITS := {
	"head":  {"swing": 6.0,  "twist": 5.0},
	"leg_l": {"swing": 25.0, "twist": 8.0},
	"leg_r": {"swing": 25.0, "twist": 8.0},
	"arm_l": {"swing": 50.0, "twist": 20.0},
	"arm_r": {"swing": 50.0, "twist": 20.0},
}

func _initialize() -> void:
	var ps: PackedScene = load("res://characters/gallo/mesh/gallo.glb")
	var src: Node = ps.instantiate()
	var skel: Skeleton3D = _find(src, "Skeleton3D")
	var mesh_inst: MeshInstance3D = _find(src, "gallo")
	if skel == null or mesh_inst == null:
		push_error("No se encontro Skeleton3D o malla"); quit(); return

	# Transform absoluto del skeleton dentro del glb (Armature * Skeleton)
	var skel_xform: Transform3D = skel.transform
	var p: Node = skel.get_parent()
	while p != null and p != src:
		skel_xform = p.transform * skel_xform
		p = p.get_parent()

	# --- Raiz CharacterBody3D ---
	var root := CharacterBody3D.new()
	root.name = "Gallo"
	root.set_script(load("res://characters/gallo/gallo.gd"))

	# Collider de caminar (capsula como el placeholder anterior)
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new(); cap.radius = 0.4; cap.height = 1.7
	cs.shape = cap
	cs.transform.origin = Vector3(0, 0.85, 0)  # centrado en altura
	root.add_child(cs)

	# Skeleton3D como hijo directo (lo exige network_manager)
	skel.get_parent().remove_child(skel)
	skel.name = "Skeleton3D"
	skel.transform = skel_xform
	root.add_child(skel)

	# Reasegurar que la malla apunta al skeleton
	mesh_inst.skeleton = NodePath("..")

	# --- Crear un PhysicalBone3D por hueso ---
	for i in skel.get_bone_count():
		var bn: String = skel.get_bone_name(i)
		var rest: Transform3D = skel.get_bone_global_rest(i)   # en espacio skeleton
		var head: Vector3 = rest.origin
		var tail: Vector3 = TAILS.get(bn, head + Vector3(0, 0.2, 0))
		var dir: Vector3 = tail - head
		var length: float = max(dir.length(), 0.05)
		var mid: Vector3 = (head + tail) * 0.5

		var pb := PhysicalBone3D.new()
		pb.name = bn
		pb.bone_name = bn
		pb.mass = MASSES.get(bn, 1.0)
		pb.transform = rest  # PB en el origen del hueso (espacio skeleton)
		# Root (torso) libre; los demas con CONE limitado al padre (estabilidad).
		if skel.get_bone_parent(i) < 0:
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		else:
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			# Aplicar limites del cono en grados (rutas verificadas con get_property_list).
			var lim: Dictionary = CONE_LIMITS.get(bn, {"swing": 30.0, "twist": 10.0})
			pb.set("joint_constraints/swing_span", lim["swing"])
			pb.set("joint_constraints/twist_span", lim["twist"])

		# Capsula alineada al hueso
		var bcs := CollisionShape3D.new()
		bcs.name = "Collision"
		var bcap := CapsuleShape3D.new()
		bcap.height = length
		bcap.radius = clampf(length * 0.22, 0.05, 0.22)
		bcs.shape = bcap
		var cap_global := Transform3D(_basis_from_y(dir), mid)  # espacio skeleton
		bcs.transform = rest.affine_inverse() * cap_global       # local al PB
		pb.add_child(bcs)

		skel.add_child(pb)

	# --- Fijar owners para empaquetar ---
	_set_owner_rec(root, root)

	# --- Guardar .tscn ---
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack fallo: %d" % err); quit(); return
	err = ResourceSaver.save(packed, "res://characters/gallo/gallo.tscn")
	print("Guardado gallo.tscn err=", err)
	print("PhysicalBones creados: ", skel.get_bone_count())
	quit()

func _basis_from_y(d: Vector3) -> Basis:
	var y := d.normalized()
	var x := Vector3.RIGHT
	if absf(y.dot(x)) > 0.99:
		x = Vector3.FORWARD
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	return Basis(x, y, z)

func _set_owner_rec(n: Node, owner: Node) -> void:
	for c in n.get_children():
		c.owner = owner
		_set_owner_rec(c, owner)

func _find(n: Node, nm: String) -> Node:
	if n.name == nm:
		return n
	for c in n.get_children():
		var r: Node = _find(c, nm)
		if r: return r
	return null
