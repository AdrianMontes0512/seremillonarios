extends Node3D
class_name ActiveRagdollController

# ============================================================================
# ACTIVE RAGDOLL CONTROLLER (6 huesos · RigidBody3D + Generic6DOFJoint3D)
# Estilo Gang Beasts. Todo es físico: NO hay CharacterBody3D.
#
# El TORSO es el cuerpo lógico raíz (pero igual es dinámico). Los 5 miembros
# cuelgan del torso por joints 6DOF que actúan como "músculos" (angular spring
# con punto de equilibrio = pose de reposo). El equilibrio erguido del torso se
# logra con un controlador PID que aplica torque directo al torso.
#
# Acciones de InputMap requeridas:
#   move_left / move_right / move_forward / move_back  (WASD / stick)
#   raise_arms   (mantener: levanta los brazos sobre la cabeza)
#   dive         (tirarse hacia adelante)
#   punch_left   (click izq)   punch_right  (click der)
#   grab_left / grab_right     (los maneja GrabController en cada mano)
# ============================================================================

# --- Referencias a los 6 RigidBody3D (asignar en el Inspector) ---
@export var torso: RigidBody3D
@export var head: RigidBody3D
@export var arm_l: RigidBody3D
@export var arm_r: RigidBody3D
@export var leg_l: RigidBody3D
@export var leg_r: RigidBody3D

# --- Referencias a los 5 Generic6DOFJoint3D (Torso <-> miembro) ---
@export var joint_head: Generic6DOFJoint3D
@export var joint_arm_l: Generic6DOFJoint3D
@export var joint_arm_r: Generic6DOFJoint3D
@export var joint_leg_l: Generic6DOFJoint3D
@export var joint_leg_r: Generic6DOFJoint3D

# --- Tuning de locomoción ---
@export var move_force: float = 1200.0   # fuerza horizontal aplicada al torso (N)
@export var max_speed: float = 4.0        # tope de velocidad horizontal (m/s)

# --- Tuning del equilibrio (PID del torso) ---
@export var upright_stiffness: float = 900.0   # Kp: cuánto torque por radián de inclinación
@export var upright_damping: float = 120.0     # Kd: frena la velocidad angular (anti-oscilación)

# --- Tuning de los "músculos" (angular spring de los joints) ---
@export var muscle_stiffness: float = 120.0    # rigidez del resorte angular
@export var muscle_damping: float = 8.0        # amortiguación del resorte
@export var head_swing_deg: float = 8.0        # límite angular cabeza (casi rígida)
@export var arm_swing_deg: float = 90.0        # límite angular brazos
@export var leg_swing_deg: float = 35.0        # límite angular piernas

# --- Brazos arriba / Dive ---
@export var arm_raise_angle_deg: float = 110.0 # ángulo objetivo al levantar brazos
@export var dive_impulse: float = 9.0          # impulso hacia adelante del dive
@export var dive_duration: float = 0.9         # cuánto dura el colapso del dive

# --- Punch ---
@export var punch_torque: float = 18.0         # torque-impulso del golpe
@export var punch_forward_impulse: float = 6.0 # impulso lineal hacia adelante de la mano
@export var punch_cooldown: float = 0.35

# --- Knockout ---
@export var ko_velocity_threshold: float = 9.0 # velocidad relativa de impacto que noquea
@export var ko_duration: float = 2.5           # segundos desmayado

# --- Estado interno ---
var _balance_scale: float = 1.0   # 1 = equilibrio normal, 0 = ragdoll pasivo (dive/KO)
var _dive_timer: float = 0.0
var _ko_timer: float = 0.0
var _punch_cd_l: float = 0.0
var _punch_cd_r: float = 0.0
var _arms_up: float = 0.0         # 0..1 interpolado, cuánto están levantados los brazos

# Cache de huesos para iterar
var _bones: Array[RigidBody3D] = []


func _ready() -> void:
	_bones = [torso, head, arm_l, arm_r, leg_l, leg_r]

	# 1) Que los huesos del MISMO personaje NO colisionen entre sí (si lo hicieran,
	#    los joints pelearían contra la auto-colisión y el ragdoll vibraría).
	for a in _bones:
		for b in _bones:
			if a != b:
				a.add_collision_exception_with(b)

	# 2) Los RigidBody no deben dormirse (los motores deben seguir actuando).
	for b in _bones:
		b.can_sleep = false
		b.contact_monitor = true
		b.max_contacts_reported = 4

	# 3) Centro de masa bajo en el torso => más estable (Gang Beasts estable).
	torso.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	torso.center_of_mass = Vector3(0, -0.15, 0)

	# 4) Configurar cada joint como "músculo" (límite + angular spring).
	_setup_muscle(joint_head, head_swing_deg)
	_setup_muscle(joint_arm_l, arm_swing_deg)
	_setup_muscle(joint_arm_r, arm_swing_deg)
	_setup_muscle(joint_leg_l, leg_swing_deg)
	_setup_muscle(joint_leg_r, leg_swing_deg)

	# 5) Escuchar impactos para el knockout (en torso y cabeza, que son los "vitales").
	torso.body_entered.connect(_on_bone_impact)
	head.body_entered.connect(_on_bone_impact)


# Configura UN joint 6DOF como músculo: limita el rango angular en los 3 ejes
# y activa un resorte angular con punto de equilibrio 0 (pose de reposo).
func _setup_muscle(j: Generic6DOFJoint3D, swing_deg: float) -> void:
	if j == null:
		return
	var lim: float = deg_to_rad(swing_deg)
	for axis in ["x", "y", "z"]:
		# Límite angular duro (tope mecánico de la articulación).
		j.call("set_flag_" + axis, Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
		j.call("set_param_" + axis, Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -lim)
		j.call("set_param_" + axis, Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, lim)
		# Resorte angular = "músculo" que tira hacia la pose de reposo (equilibrium).
		j.call("set_flag_" + axis, Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_SPRING, true)
		j.call("set_param_" + axis, Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, muscle_stiffness)
		j.call("set_param_" + axis, Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_DAMPING, muscle_damping)
		j.call("set_param_" + axis, Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_EQUILIBRIUM_POINT, 0.0)


# Cambia el punto de equilibrio del resorte de un eje (para levantar brazos, etc.).
func _set_equilibrium(j: Generic6DOFJoint3D, axis: String, angle_rad: float) -> void:
	j.call("set_param_" + axis, Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_EQUILIBRIUM_POINT, angle_rad)


# Cambia la rigidez del resorte de los 3 ejes de un joint (0 = músculo "muerto").
func _set_muscle_stiffness(j: Generic6DOFJoint3D, stiffness: float, damping: float) -> void:
	if j == null:
		return
	for axis in ["x", "y", "z"]:
		j.call("set_param_" + axis, Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, stiffness)
		j.call("set_param_" + axis, Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_DAMPING, damping)


# ============================================================================
# BUCLE DE FÍSICA
# ============================================================================
func _physics_process(delta: float) -> void:
	_update_timers(delta)

	# Si está noqueado, no hay control: ragdoll puramente pasivo.
	if _ko_timer > 0.0:
		return

	_apply_locomotion(delta)
	_apply_upright(delta)
	_apply_arms(delta)


func _update_timers(delta: float) -> void:
	if _punch_cd_l > 0.0: _punch_cd_l -= delta
	if _punch_cd_r > 0.0: _punch_cd_r -= delta

	if _ko_timer > 0.0:
		_ko_timer -= delta
		if _ko_timer <= 0.0:
			_recover_from_ko()

	if _dive_timer > 0.0:
		_dive_timer -= delta
		_balance_scale = 0.0   # durante el dive no se endereza (colapsa)
		if _dive_timer <= 0.0:
			_balance_scale = 1.0


# --- 1) LOCOMOCIÓN: fuerza horizontal al torso, con tope de velocidad ---
func _apply_locomotion(_delta: float) -> void:
	var input := Vector3(
		Input.get_axis("move_left", "move_right"),
		0.0,
		Input.get_axis("move_forward", "move_back")
	)
	if input.length() > 1.0:
		input = input.normalized()

	if input.length() > 0.01:
		# Solo empujamos si aún no llegamos a la velocidad máxima en esa dirección.
		var horiz := Vector3(torso.linear_velocity.x, 0.0, torso.linear_velocity.z)
		if horiz.dot(input) < max_speed:
			torso.apply_central_force(input * move_force)
		# Orientar el frente (-Z) del torso hacia la dirección de avance (yaw suave).
		_face_direction(input)


# Gira el torso (solo yaw) para mirar hacia `dir`, vía torque alrededor de Y.
func _face_direction(dir: Vector3) -> void:
	var fwd := -torso.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return
	fwd = fwd.normalized()
	# Producto cruz Y nos da el sentido del giro necesario.
	var turn := fwd.cross(dir).y
	torso.apply_torque(Vector3.UP * turn * upright_stiffness * 0.5)


# --- 2) EQUILIBRIO ERGUIDO: PID que aplica torque al torso ---
func _apply_upright(_delta: float) -> void:
	if _balance_scale <= 0.0:
		return
	var up := torso.global_transform.basis.y
	var axis := up.cross(Vector3.UP)          # eje de corrección
	var angle := up.angle_to(Vector3.UP)      # error (rad)
	# PID (P + D): torque = Kp*angle*axis - Kd*ω, escalado por _balance_scale.
	var p_term := axis.normalized() * angle * upright_stiffness if axis.length() > 0.001 else Vector3.ZERO
	var d_term := torso.angular_velocity * upright_damping
	# Solo corregimos inclinación (X/Z); el yaw lo maneja _face_direction.
	var torque := (p_term - d_term) * _balance_scale
	torque.y = 0.0
	torso.apply_torque(torque)


# --- 3) BRAZOS ARRIBA: interpola el equilibrio del resorte de los brazos ---
func _apply_arms(delta: float) -> void:
	var want_up := Input.is_action_pressed("raise_arms")
	_arms_up = move_toward(_arms_up, 1.0 if want_up else 0.0, delta * 5.0)
	var target := deg_to_rad(arm_raise_angle_deg) * _arms_up
	# Eje X del joint = levantar/bajar el brazo (ajustar según orientación del joint).
	_set_equilibrium(joint_arm_l, "x", -target)
	_set_equilibrium(joint_arm_r, "x", -target)


# ============================================================================
# ACCIONES (llamar desde _unhandled_input o desde aquí con is_action_just_pressed)
# ============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if _ko_timer > 0.0:
		return
	if event.is_action_pressed("punch_left"):
		_punch(arm_l, true)
	elif event.is_action_pressed("punch_right"):
		_punch(arm_r, false)
	elif event.is_action_pressed("dive"):
		_dive()


# --- GOLPE: torque-impulso al brazo hacia adelante + impulso de la mano ---
func _punch(arm: RigidBody3D, is_left: bool) -> void:
	if is_left and _punch_cd_l > 0.0: return
	if not is_left and _punch_cd_r > 0.0: return
	if is_left: _punch_cd_l = punch_cooldown
	else: _punch_cd_r = punch_cooldown

	var fwd := -torso.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	# Eje de giro del brazo para lanzarlo hacia adelante = eje derecho del torso.
	var swing_axis := torso.global_transform.basis.x
	if is_left:
		swing_axis = -swing_axis
	arm.apply_torque_impulse(swing_axis * punch_torque)
	arm.apply_central_impulse(fwd * punch_forward_impulse)


# --- DIVE: impulso adelante + apaga el equilibrio un rato (colapsa) ---
func _dive() -> void:
	var fwd := -torso.global_transform.basis.z
	fwd.y = 0.2  # un poco hacia arriba para que "salte" al lanzarse
	torso.apply_central_impulse(fwd.normalized() * dive_impulse)
	_dive_timer = dive_duration
	# Aflojar también los músculos de las piernas para que el colapso se vea blando.
	_set_muscle_stiffness(joint_leg_l, muscle_stiffness * 0.2, muscle_damping)
	_set_muscle_stiffness(joint_leg_r, muscle_stiffness * 0.2, muscle_damping)
	get_tree().create_timer(dive_duration).timeout.connect(func ():
		_set_muscle_stiffness(joint_leg_l, muscle_stiffness, muscle_damping)
		_set_muscle_stiffness(joint_leg_r, muscle_stiffness, muscle_damping)
	)


# ============================================================================
# KNOCKOUT por impacto
# ============================================================================
func _on_bone_impact(body: Node) -> void:
	if _ko_timer > 0.0:
		return
	if not (body is RigidBody3D or body is CharacterBody3D):
		# también podría ser StaticBody; medimos contra velocidad propia
		pass
	# Velocidad relativa de impacto (proxy de la fuerza del golpe).
	var other_vel := Vector3.ZERO
	if body is RigidBody3D:
		other_vel = (body as RigidBody3D).linear_velocity
	var rel_speed := (torso.linear_velocity - other_vel).length()
	if rel_speed >= ko_velocity_threshold:
		_knockout()


# Entrar en KO: músculos a 0 (ragdoll pasivo) + sin equilibrio, por ko_duration.
func _knockout() -> void:
	_ko_timer = ko_duration
	_balance_scale = 0.0
	# Músculos a 0 Y límites angulares desactivados → ragdoll PASIVO total
	# (se desploma de verdad como desmayado, no solo se hunde).
	for j in [joint_head, joint_arm_l, joint_arm_r, joint_leg_l, joint_leg_r]:
		_set_muscle_stiffness(j, 0.0, 0.0)
		for axis in ["x", "y", "z"]:
			j.call("set_flag_" + axis, Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, false)


# Recuperarse: restaurar músculos y equilibrio (el personaje se vuelve a parar).
func _recover_from_ko() -> void:
	_balance_scale = 1.0
	_setup_muscle(joint_head, head_swing_deg)
	_setup_muscle(joint_arm_l, arm_swing_deg)
	_setup_muscle(joint_arm_r, arm_swing_deg)
	_setup_muscle(joint_leg_l, leg_swing_deg)
	_setup_muscle(joint_leg_r, leg_swing_deg)
