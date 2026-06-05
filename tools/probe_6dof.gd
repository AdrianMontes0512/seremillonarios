extends SceneTree
func _initialize() -> void:
	var j := Generic6DOFJoint3D.new()
	print("=== Generic6DOFJoint3D métodos relevantes ===")
	for m in j.get_method_list():
		if m.name.begins_with("set_param") or m.name.begins_with("set_flag"):
			print("  ", m.name)
	print("=== Param enum ===")
	for k in ["PARAM_ANGULAR_LOWER_LIMIT","PARAM_ANGULAR_UPPER_LIMIT","PARAM_ANGULAR_SPRING_STIFFNESS","PARAM_ANGULAR_SPRING_DAMPING","PARAM_ANGULAR_SPRING_EQUILIBRIUM_POINT","PARAM_ANGULAR_MOTOR_TARGET_VELOCITY","PARAM_ANGULAR_MOTOR_FORCE_LIMIT"]:
		print("  ", k, " = ", Generic6DOFJoint3D[k] if k in Generic6DOFJoint3D else "N/A")
	print("=== Flag enum ===")
	for k in ["FLAG_ENABLE_ANGULAR_LIMIT","FLAG_ENABLE_ANGULAR_SPRING","FLAG_ENABLE_MOTOR","FLAG_ENABLE_LINEAR_SPRING"]:
		print("  ", k, " = ", Generic6DOFJoint3D[k] if k in Generic6DOFJoint3D else "N/A")
	j.free()
	var rb := RigidBody3D.new()
	print("=== RigidBody3D props/métodos clave ===")
	for p in ["center_of_mass","center_of_mass_mode","contact_monitor","max_contacts_reported","can_sleep","angular_damp","linear_damp"]:
		print("  prop ", p, ": ", (p in rb))
	for m in ["apply_central_force","apply_force","apply_torque","apply_central_impulse","apply_impulse","apply_torque_impulse","add_collision_exception_with"]:
		print("  method ", m, ": ", rb.has_method(m))
	print("  CENTER_OF_MASS_MODE_CUSTOM = ", RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM)
	rb.free()
	quit()
