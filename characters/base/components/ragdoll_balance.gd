class_name RagdollBalance
extends RefCounted

# ============================================================
# Componente BALANCE: mantiene el torso a su altura (hover) y vertical
# (enderezado), y la CABEZA rígida respecto al torso.
# Opera sobre el personaje `c` (ragdoll_character.gd).
# Contrato disponible en `c`: _torso, bone("head"), _target_height,
# hover_strength, hover_damp, balance_strength, MAX_RIGHT_SPEED.
# ============================================================

func tick(c, delta: float) -> void:
	var t: PhysicalBone3D = c._torso
	if t == null:
		return

	# --- Hover: resorte vertical que sostiene el torso a _target_height ---
	var y_err: float = c._target_height - t.global_position.y
	var up_impulse: float = (y_err * c.hover_strength - t.linear_velocity.y * c.hover_damp) * t.mass * delta
	t.apply_central_impulse(Vector3.UP * up_impulse)

	# --- Enderezado: alinea el "arriba" del torso con el mundo ---
	var up: Vector3 = t.global_transform.basis.y
	var axis: Vector3 = up.cross(Vector3.UP)
	if axis.length() > 0.001:
		var angle: float = up.angle_to(Vector3.UP)
		var target_w: Vector3 = axis.normalized() * minf(angle * c.balance_strength, c.MAX_RIGHT_SPEED)
		t.angular_velocity = t.angular_velocity.lerp(target_w, 0.4)
	else:
		t.angular_velocity = t.angular_velocity * 0.5

	# --- Cabeza: la mantenemos casi rígida respecto al torso ---
	_tick_head(c, t, delta)


# Constantes locales para el control de la cabeza.
# Ajustan el "feel": firme pero con micro-movimiento, ni congelada ni bamboleante.
const HEAD_ALIGN_SPEED: float = 18.0   # ganancia proporcional al error de orientacion
const HEAD_MAX_W: float = 14.0         # tope de velocidad angular correctiva (rad/s)
const HEAD_LERP: float = 0.35          # suavizado para no tironear (igual estilo que el torso)
const HEAD_ANCHOR_STR: float = 28.0    # fuerza del resorte de posicion (ancla al cuello)
const HEAD_ANCHOR_DAMP: float = 6.0    # amortiguacion del ancla de posicion
const HEAD_NECK_OFFSET: float = 0.50   # distancia head-torso sobre el eje +Y del torso

func _tick_head(c, t: PhysicalBone3D, delta: float) -> void:
	var h: PhysicalBone3D = c.bone("head")
	if h == null:
		return

	# 1) Alineacion de orientacion: rotacion que lleva la basis de la cabeza
	#    a la basis del torso. La basis es ortonormal, asi que su transpuesta
	#    es su inversa: delta = torso * head^-1.
	var b_head: Basis = h.global_transform.basis.orthonormalized()
	var b_torso: Basis = t.global_transform.basis.orthonormalized()
	var delta_basis: Basis = b_torso * b_head.transposed()

	# Extraemos el error como eje-angulo desde el cuaternion de la rotacion delta.
	var q: Quaternion = delta_basis.get_rotation_quaternion()
	var angle: float = 2.0 * acos(clampf(q.w, -1.0, 1.0))
	var target_w: Vector3 = h.angular_velocity
	if angle > 0.001:
		# Eje de correccion (componente vectorial del cuaternion, normalizada).
		var axis: Vector3 = Vector3(q.x, q.y, q.z)
		if axis.length() > 0.0001:
			axis = axis.normalized()
			# Mantenemos el angulo en [-PI, PI] para girar por el camino corto.
			if angle > PI:
				angle = angle - TAU
			var w_mag: float = clampf(angle * HEAD_ALIGN_SPEED, -HEAD_MAX_W, HEAD_MAX_W)
			target_w = axis * w_mag
	# Lerp suave hacia la velocidad objetivo (control critico-amortiguado, como el torso).
	h.angular_velocity = h.angular_velocity.lerp(target_w, HEAD_LERP)

	# 2) Ancla de posicion: empujamos suavemente la cabeza hacia el punto objetivo
	#    = posicion del torso + offset hacia arriba EN EL EJE del torso (no del mundo),
	#    para que acompane la inclinacion sin pelear con el joint.
	var target_pos: Vector3 = t.global_position + b_torso.y * HEAD_NECK_OFFSET
	var pos_err: Vector3 = target_pos - h.global_position
	var rel_vel: Vector3 = h.linear_velocity - t.linear_velocity
	var anchor_impulse: Vector3 = (pos_err * HEAD_ANCHOR_STR - rel_vel * HEAD_ANCHOR_DAMP) * h.mass * delta
	h.apply_central_impulse(anchor_impulse)
