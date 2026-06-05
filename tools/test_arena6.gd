extends SceneTree
var f := 0
func _initialize():
	var ps = load("res://scenes/arena_6dof.tscn")
	if ps == null: print("ERROR: no carga arena_6dof.tscn"); quit(); return
	get_root().add_child(ps.instantiate())
func _process(_d):
	f += 1
	if f == 80:
		var img = get_root().get_texture().get_image()
		if img: img.save_png("/home/mva/Desktop/seremosmillonarios/tools/arena6_check.png")
		var g = get_root().find_child("Gallo", true, false)
		var t = g.get("torso") if g else null
		if t: print("OK gallo en arena, torso_y=%.2f up=%.2f" % [t.global_position.y, t.global_transform.basis.y.dot(Vector3.UP)])
		quit()
	return false
