extends SceneTree
func _initialize() -> void:
	var pb := PhysicalBone3D.new()
	print("has linear_velocity: ", "linear_velocity" in pb)
	print("has angular_velocity: ", "angular_velocity" in pb)
	print("has apply_central_impulse: ", pb.has_method("apply_central_impulse"))
	print("has apply_torque_impulse: ", pb.has_method("apply_torque_impulse"))
	print("has gravity_scale: ", "gravity_scale" in pb)
	pb.free()
	quit()
