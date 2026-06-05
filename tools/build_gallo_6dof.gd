extends SceneTree

# Construye characters/gallo/gallo_6dof.tscn: active ragdoll de 6 RigidBody3D
# unidos por 5 Generic6DOFJoint3D, con las 6 piezas de malla del gallo.
# Posiciones de los huesos (centro de cada pieza) en coords Godot (Y-up),
# convertidas desde los centros que reportó Blender (Z-up): (x,y,z)_godot = (x, z, -y).

const BONE_POS := {
	"Torso": Vector3(0.0, 1.093, 0.083),
	"Head":  Vector3(0.0, 1.492, 0.172),
	"ArmL":  Vector3(0.3, 1.0, -0.02),
	"ArmR":  Vector3(-0.3, 1.0, -0.02),
	"LegL":  Vector3(0.13, 0.088, 0.052),
	"LegR":  Vector3(-0.13, 0.088, 0.052),
}
# Punto de articulación (donde va el joint) en coords Godot.
const JOINT_POS := {
	"Head": Vector3(0.0, 1.35, 0.0),
	"ArmL": Vector3(0.22, 1.28, 0.0),
	"ArmR": Vector3(-0.22, 1.28, 0.0),
	"LegL": Vector3(0.11, 0.85, 0.0),
	"LegR": Vector3(-0.11, 0.85, 0.0),
}
const MASS := {"Torso": 6.0, "Head": 1.5, "ArmL": 1.0, "ArmR": 1.0, "LegL": 2.0, "LegR": 2.0}
# Nombre de la pieza de malla en el glb por hueso.
const MESH_NAME := {
	"Torso": "gallo_torso", "Head": "gallo_head", "ArmL": "gallo_arm_l",
	"ArmR": "gallo_arm_r", "LegL": "gallo_leg_l", "LegR": "gallo_leg_r",
}

func _initialize() -> void:
	var ps: PackedScene = load("res://characters/gallo/mesh/gallo_parts.glb")
	var src: Node = ps.instantiate()

	var ctrl_script := load("res://characters/base/ActiveRagdollController.gd")
	var grab_script := load("res://characters/base/GrabController.gd")

	var root := Node3D.new()
	root.name = "Gallo"
	root.set_script(ctrl_script)

	var bones := Node3D.new(); bones.name = "Bones"; root.add_child(bones)
	var joints := Node3D.new(); joints.name = "Joints"; root.add_child(joints)

	var rb_map := {}
	for bn in ["Torso", "Head", "ArmL", "ArmR", "LegL", "LegR"]:
		var rb := RigidBody3D.new()
		rb.name = bn
		rb.mass = MASS[bn]
		rb.position = BONE_POS[bn]
		rb.can_sleep = false
		rb.contact_monitor = true
		rb.max_contacts_reported = 4
		rb.linear_damp = 0.5
		rb.angular_damp = 3.0
		bones.add_child(rb)

		# Malla: la pieza del glb, reparentada bajo el RigidBody (local identidad).
		var mesh_src: MeshInstance3D = _find(src, MESH_NAME[bn]) as MeshInstance3D
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh"
		mesh.mesh = mesh_src.mesh
		rb.add_child(mesh)

		# Colisión: caja desde el AABB de la malla (alineada, simple y robusta).
		var aabb: AABB = mesh_src.mesh.get_aabb()
		var cs := CollisionShape3D.new(); cs.name = "Col"
		var box := BoxShape3D.new()
		box.size = aabb.size
		cs.shape = box
		cs.position = aabb.position + aabb.size * 0.5
		rb.add_child(cs)

		rb_map[bn] = rb

	# --- Joints 6DOF: Torso <-> cada miembro ---
	var torso: RigidBody3D = rb_map["Torso"]
	var joint_map := {}
	for bn in ["Head", "ArmL", "ArmR", "LegL", "LegR"]:
		var j := Generic6DOFJoint3D.new()
		j.name = "J_" + bn
		j.position = JOINT_POS[bn]
		joints.add_child(j)
		j.node_a = j.get_path_to(torso)
		j.node_b = j.get_path_to(rb_map[bn])
		joint_map[bn] = j

	# --- Asignar referencias @export del ActiveRagdollController ---
	root.set("torso", torso)
	root.set("head", rb_map["Head"])
	root.set("arm_l", rb_map["ArmL"])
	root.set("arm_r", rb_map["ArmR"])
	root.set("leg_l", rb_map["LegL"])
	root.set("leg_r", rb_map["LegR"])
	root.set("joint_head", joint_map["Head"])
	root.set("joint_arm_l", joint_map["ArmL"])
	root.set("joint_arm_r", joint_map["ArmR"])
	root.set("joint_leg_l", joint_map["LegL"])
	root.set("joint_leg_r", joint_map["LegR"])

	# --- GrabController en cada brazo ---
	for side in [["ArmL", "grab_left"], ["ArmR", "grab_right"]]:
		var g := Node.new()
		g.name = "Grab"
		g.set_script(grab_script)
		rb_map[side[0]].add_child(g)
		g.set("hand_body", rb_map[side[0]])
		g.set("action", side[1])

	# --- Owners + guardar ---
	_set_owner_rec(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack fallo %d" % err); quit(); return
	err = ResourceSaver.save(packed, "res://characters/gallo/gallo_6dof.tscn")
	print("Guardado gallo_6dof.tscn err=", err)
	quit()

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
