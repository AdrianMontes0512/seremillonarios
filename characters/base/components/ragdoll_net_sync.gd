extends RefCounted

# Componente de SINCRONIZACIÓN DE RED del active ragdoll 6DOF.
# El host obtiene get_state() y lo transmite; el cliente congela los cuerpos
# (set_client_mode) y aplica apply_state() cada tick (lerp suave).
# Ver docs/refine/NET-CONTRACT.md sección "Componente de red".

# Nombres lógicos en el MISMO orden que bodies(): torso, head, arm_l, arm_r, leg_l, leg_r.
const LOGICAL_NAMES := ["Torso", "Head", "ArmL", "ArmR", "LegL", "LegR"]

# Factor de interpolación hacia el estado recibido.
const LERP_FACTOR := 0.35


# Devuelve los 6 RigidBody3D en orden fijo, filtrando nulls por seguridad.
func bodies(char) -> Array:
	var list := [char.torso, char.head, char.arm_l, char.arm_r, char.leg_l, char.leg_r]
	var result := []
	for b in list:
		if b != null:
			result.append(b)
	return result


# Estado por cuerpo: nombre lógico, posición/rotación globales y velocidades.
func get_state(char) -> Array:
	var state := []
	var bs := bodies(char)
	for i in range(bs.size()):
		var b = bs[i]
		# El índice coincide con LOGICAL_NAMES porque bodies() respeta el orden fijo.
		var name = LOGICAL_NAMES[i] if i < LOGICAL_NAMES.size() else b.name
		state.append({
			"n": name,
			"p": b.global_position,
			"r": b.global_rotation,
			"lv": b.linear_velocity,
			"av": b.angular_velocity,
		})
	return state


# Aplica el estado recibido en el cliente: lerp de posición y rotación (quaternion).
# Los cuerpos están congelados (kinematic), así que escribir el transform es válido.
func apply_state(char, state: Array) -> void:
	if state.is_empty():
		return
	# Mapa nombre lógico -> RigidBody3D para ubicar cada cuerpo recibido.
	var by_name := {}
	var bs := bodies(char)
	for i in range(bs.size()):
		var name = LOGICAL_NAMES[i] if i < LOGICAL_NAMES.size() else bs[i].name
		by_name[name] = bs[i]
	for entry in state:
		var name = entry.get("n", "")
		if not by_name.has(name):
			continue
		var b = by_name[name]
		var target_pos: Vector3 = entry.get("p", b.global_position)
		var target_rot: Vector3 = entry.get("r", b.global_rotation)
		# Lerp de posición.
		b.global_position = b.global_position.lerp(target_pos, LERP_FACTOR)
		# Interpolación de rotación vía quaternions (slerp), válida en Godot 4.
		var current_q := Quaternion(b.global_transform.basis)
		var target_q := Quaternion.from_euler(target_rot)
		var new_basis := Basis(current_q.slerp(target_q, LERP_FACTOR))
		var t: Transform3D = b.global_transform
		t.basis = new_basis
		b.global_transform = t


# Modo cliente: congela cada cuerpo como kinematic (la red controla su transform).
func set_client_mode(char) -> void:
	for b in bodies(char):
		b.freeze = true
		b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
