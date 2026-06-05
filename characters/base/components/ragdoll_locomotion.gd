class_name RagdollLocomotion
extends RefCounted

# ============================================================
# Componente LOCOMOCIÓN (WS-B): mueve el personaje como UNIDAD y da
# estabilidad a las piernas. Feel "estable pero con vida" (el gallo).
#
# Idea general:
#  - Al haber input, empujamos el torso en la dirección `dir` y ADEMÁS
#    arrastramos las piernas en la misma dirección, más un resorte que tira
#    de cada pierna hacia su posición objetivo bajo la cadera correspondiente
#    (debajo del torso en XZ, a su separación x±0.11). Así el conjunto se
#    traslada junto y las piernas no quedan atrás.
#  - Sin input, recogemos las piernas bajo el torso (resorte vertical/lateral)
#    para que no se abran (splay) ni se arrastren, limitando velocidades.
#  - Yaw: giramos suavemente el torso para que su frente (-Z) mire hacia `dir`,
#    controlando SOLO el componente Y de angular_velocity (el enderezado
#    vertical lo maneja OTRO componente; no lo tocamos).
#
# Contrato en `c`: _torso, bone("leg_l"/"leg_r"), move_force, jump_force,
# _stun, attempt_attack(), get_physics_process_delta_time().
# Acciones de input: move_left/right/forward/back, jump, attack.
# ============================================================

# --- Constantes de tuning ---------------------------------------------------
const LEG_FOLLOW_FORCE: float = 0.85   # cuánto arrastra el input a cada pierna (frac. del empuje del torso)
const LEG_RECOVER_FORCE: float = 28.0  # rigidez del resorte que recoge la pierna bajo la cadera
const LEG_RECOVER_DAMP: float = 6.0    # amortiguación del resorte de piernas
const HIP_OFFSET_X: float = 0.11       # separación lateral de cada cadera respecto al torso
const LEG_TARGET_DROP: float = 0.85    # cuánto cuelga la pierna por debajo del torso (objetivo Y)
const TURN_SPEED: float = 8.0          # velocidad de giro del yaw hacia la dirección de movimiento
const MAX_LEG_SPEED: float = 6.0       # tope de velocidad lineal de piernas (anti-vibración)
const MAX_YAW_SPEED: float = 6.0       # tope del componente Y de angular_velocity del torso
const MAX_MOVE_SPEED: float = 3.0      # tope de velocidad horizontal del torso (evita acelerar e inclinarse)


# Aplica el modelo de movimiento. `dir` ya viene en plano XZ (puede ser cero).
func _drive(c, dir: Vector3, do_jump: bool, delta: float) -> void:
	var t: PhysicalBone3D = c._torso
	if t == null:
		return

	var leg_l: PhysicalBone3D = c.bone("leg_l")
	var leg_r: PhysicalBone3D = c.bone("leg_r")
	var has_input: bool = dir.length() > 0.01

	# --- 1. Traslación del cuerpo como unidad -------------------------------
	if has_input:
		# Empuje del torso, PERO con tope de velocidad horizontal: si ya va a
		# la velocidad máxima en esa dirección, no seguir acelerando (evita que
		# se incline cada vez más al acumular velocidad).
		var horiz_v: Vector3 = Vector3(t.linear_velocity.x, 0.0, t.linear_velocity.z)
		if horiz_v.dot(dir) < MAX_MOVE_SPEED:
			t.apply_central_impulse(dir * c.move_force * t.mass * delta)
		# Arrastre de las piernas en la misma dirección para que sigan al torso.
		if leg_l != null:
			leg_l.apply_central_impulse(dir * c.move_force * leg_l.mass * delta * LEG_FOLLOW_FORCE)
		if leg_r != null:
			leg_r.apply_central_impulse(dir * c.move_force * leg_r.mass * delta * LEG_FOLLOW_FORCE)

		# --- 3. Orientación (yaw): frente (-Z) hacia `dir` ------------------
		# yaw objetivo: atan2 sobre la dirección horizontal. El frente es -Z,
		# por eso usamos (-dir) para alinear -Z con `dir`.
		var target_yaw: float = atan2(-dir.x, -dir.z)
		var cur_yaw: float = t.global_transform.basis.get_euler().y
		var yaw_err: float = wrapf(target_yaw - cur_yaw, -PI, PI)
		# Solo ajustamos el componente Y de la velocidad angular; dejamos X/Z
		# para que el componente de balance/enderezado los gestione.
		var av: Vector3 = t.angular_velocity
		av.y = clamp(yaw_err * TURN_SPEED, -MAX_YAW_SPEED, MAX_YAW_SPEED)
		t.angular_velocity = av

	# --- 2. Resorte de recogida de piernas bajo las caderas -----------------
	# Siempre activo: mantiene las piernas debajo del torso. Sin input es la
	# única fuerza horizontal sobre las piernas, así que evita el splay.
	_recover_leg(t, leg_l, +HIP_OFFSET_X, delta)
	_recover_leg(t, leg_r, -HIP_OFFSET_X, delta)

	# --- 4. Salto -----------------------------------------------------------
	if do_jump:
		t.apply_central_impulse(Vector3.UP * c.jump_force * t.mass)


# Resorte que tira de una pierna hacia su objetivo: bajo la cadera en XZ
# (torso XZ + offset lateral según el yaw del torso) y colgando LEG_TARGET_DROP.
func _recover_leg(t: PhysicalBone3D, leg: PhysicalBone3D, offset_x: float, _delta: float) -> void:
	if leg == null:
		return
	# El offset lateral debe rotar con el torso para seguir su orientación.
	var right: Vector3 = t.global_transform.basis.x
	var target: Vector3 = t.global_position + right * offset_x

	# SOLO corregimos el plano horizontal (XZ): mantener las piernas bajo el torso.
	# La componente vertical la deja a la gravedad (las patas cuelgan solas). Si
	# tiráramos hacia abajo (target por debajo del torso), esa tensión pasaría por
	# los joints y mantendría al torso pegado al piso, impidiendo levantarse.
	var to_target: Vector3 = target - leg.global_position
	to_target.y = 0.0
	var horiz_vel: Vector3 = Vector3(leg.linear_velocity.x, 0.0, leg.linear_velocity.z)
	# Resorte amortiguado horizontal: F = k*x - d*v.
	var spring: Vector3 = to_target * LEG_RECOVER_FORCE - horiz_vel * LEG_RECOVER_DAMP
	leg.apply_central_impulse(spring * leg.mass * _delta)

	# Anti-vibración: limitar velocidad lineal de la pierna.
	if leg.linear_velocity.length() > MAX_LEG_SPEED:
		leg.linear_velocity = leg.linear_velocity.normalized() * MAX_LEG_SPEED


# --- Jugador local ----------------------------------------------------------
func tick(c, delta: float) -> void:
	var t: PhysicalBone3D = c._torso
	if t == null:
		return

	# Si está aturdido, no procesamos movimiento (igual que el remoto).
	if c._stun > 0.0:
		return

	var move_x: float = Input.get_axis("move_left", "move_right")
	var move_z: float = Input.get_axis("move_forward", "move_back")
	var dir: Vector3 = Vector3(move_x, 0.0, move_z)
	if dir.length() > 1.0:
		dir = dir.normalized()

	var do_jump: bool = Input.is_action_just_pressed("jump")
	_drive(c, dir, do_jump, delta)

	if Input.is_action_just_pressed("attack"):
		c.attempt_attack()


# --- Movimiento remoto (host aplica inputs del cliente). Mismo modelo. -------
func apply_remote(c, input: Dictionary) -> void:
	var t: PhysicalBone3D = c._torso
	if t == null:
		return
	if c._stun > 0.0:
		return

	var dir: Vector3 = Vector3.ZERO
	if input.has("dir"):
		var d: Vector3 = input["dir"]
		dir = Vector3(d.x, 0.0, d.z)
		if dir.length() > 1.0:
			dir = dir.normalized()

	var do_jump: bool = input.has("jump") and input["jump"]
	_drive(c, dir, do_jump, c.get_physics_process_delta_time())
