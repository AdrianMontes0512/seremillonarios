extends SceneTree
func _initialize() -> void:
	var ps: PackedScene = load("res://characters/gallo/mesh/gallo_parts.glb")
	var root: Node = ps.instantiate()
	print("=== ARBOL gallo_parts ===")
	_dump(root, 0)
	quit()
func _dump(n: Node, d: int) -> void:
	var extra := ""
	if n is Node3D:
		var t: Node3D = n
		extra = " pos=" + str(t.global_position)
	if n is MeshInstance3D:
		var aabb = (n as MeshInstance3D).get_aabb()
		extra += " aabb_size=" + str(aabb.size) + " aabb_center=" + str(aabb.position + aabb.size*0.5)
	print("  ".repeat(d), n.name, " : ", n.get_class(), extra)
	for c in n.get_children():
		_dump(c, d+1)
