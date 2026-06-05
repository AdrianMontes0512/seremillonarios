extends SceneTree

# Inspecciona la escena importada del gallo: arbol de nodos, skeleton y rests.
func _initialize() -> void:
	var ps: PackedScene = load("res://characters/gallo/mesh/gallo.glb")
	if ps == null:
		print("ERROR: no se pudo cargar gallo.glb"); quit(); return
	var root: Node = ps.instantiate()
	print("=== ARBOL DE NODOS ===")
	_dump(root, 0)

	var skel: Skeleton3D = _find_skel(root)
	if skel == null:
		print("ERROR: no hay Skeleton3D"); quit(); return
	print("\n=== SKELETON3D: ", skel.name, " | bones=", skel.get_bone_count(), " ===")
	for i in skel.get_bone_count():
		var rest: Transform3D = skel.get_bone_global_rest(i)
		var parent_i: int = skel.get_bone_parent(i)
		print("  [", i, "] ", skel.get_bone_name(i),
			" parent=", (skel.get_bone_name(parent_i) if parent_i >= 0 else "ROOT"),
			" origin=", rest.origin)
	quit()

func _dump(n: Node, d: int) -> void:
	print("  ".repeat(d), n.name, " : ", n.get_class())
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		print("  ".repeat(d+1), "-> mesh surfaces=", (mi.mesh.get_surface_count() if mi.mesh else 0), " skin=", mi.skin != null, " skel_path=", mi.skeleton)
	for c in n.get_children():
		_dump(c, d + 1)

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r: Skeleton3D = _find_skel(c)
		if r: return r
	return null
