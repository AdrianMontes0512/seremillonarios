class_name RagdollCombat
extends RefCounted

# ============================================================
# Componente COMBATE: punch procedural, knockdown y recuperación.
# Contrato en `c`: _torso, bone("arm_l"/"arm_r"), _stun, stun_time, is_ragdoll,
# _target_height, _stand_height, get_main_position().
# ============================================================

# --- Constantes de tuneo del golpe ---
const WINDUP_TIME: float = 0.10   # fase de carga (brazo va un poco atrás)
const SWING_TIME: float = 0.18    # fase de golpe (impulso fuerte adelante)
const PUNCH_TOTAL: float = WINDUP_TIME + SWING_TIME  # duración total ~0.28 s

const WINDUP_FORCE: float = 1.6   # impulso (hacia atrás) durante el windup
const SWING_FORCE: float = 5.5    # impulso (hacia adelante) durante el swing
const PUNCH_LIFT: float = 0.8     # pequeña elevación del brazo al golpear
const KNOCK_SPIN: float = 4.0     # spin angular extra al recibir golpe fuerte

# --- Estado del golpe en curso ---
var _next_arm: String = "arm_r"   # con qué brazo toca el próximo golpe
var _punch_arm: String = ""       # brazo del golpe actual ("" = sin golpe)
var _punch_timer: float = 0.0     # tiempo transcurrido del golpe actual


# Avanza la animación del PUNCH (windup -> swing -> retorno a reposo).
func tick(c, delta: float) -> void:
	if _punch_arm == "":
		return  # no hay golpe en curso

	var bone = c.bone(_punch_arm)
	if bone == null:
		# brazo inexistente: aborta el golpe limpiamente
		_punch_arm = ""
		_punch_timer = 0.0
		return

	# Dirección "frente" del personaje proyectada en horizontal y normalizada.
	var fwd: Vector3 = -c._torso.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.001:
		fwd = Vector3.FORWARD  # fallback si el torso quedó casi vertical
	fwd = fwd.normalized()

	_punch_timer += delta

	if _punch_timer <= WINDUP_TIME:
		# Fase WINDUP: lleva el brazo un poco hacia atrás (carga el golpe).
		bone.apply_central_impulse(-fwd * WINDUP_FORCE * delta * 60.0)
	elif _punch_timer <= PUNCH_TOTAL:
		# Fase SWING: impulso fuerte hacia adelante + pequeña elevación.
		var swing: Vector3 = fwd * SWING_FORCE + Vector3.UP * PUNCH_LIFT
		bone.apply_central_impulse(swing * delta * 60.0)
	else:
		# Golpe terminado: deja que el balance/joints regresen el brazo a reposo.
		_punch_arm = ""
		_punch_timer = 0.0


# Inicia un golpe alternando brazo izquierdo/derecho.
func punch(c) -> void:
	if _punch_arm != "":
		return  # ya hay un golpe en curso, no iniciar otro

	_punch_arm = _next_arm
	_punch_timer = 0.0
	# Alternar para el siguiente golpe.
	_next_arm = "arm_l" if _next_arm == "arm_r" else "arm_r"


# Mientras está aturdido: descuenta el stun y, al terminar, se recupera.
func tick_stunned(c, delta: float) -> void:
	c._stun -= delta
	if c._stun <= 0.0:
		_recover(c)


# Tumbar: el torso recupera gravedad, recibe el impulso y queda aturdido.
func knock_down(c, impulse: Vector3) -> void:
	c.is_ragdoll = true
	c._stun = c.stun_time
	# Cancelar cualquier golpe en curso al ser tumbado.
	_punch_arm = ""
	_punch_timer = 0.0
	if c._torso:
		c._torso.gravity_scale = 1.0
		c._torso.apply_central_impulse(impulse)
		# Pequeño spin para que el impacto se vea con más "vida".
		var spin: Vector3 = Vector3(impulse.z, 0.0, -impulse.x).normalized() * KNOCK_SPIN
		c._torso.angular_velocity += spin


# Recuperar el control: vuelve a flotar y se levanta a su altura de pie.
func _recover(c) -> void:
	c.is_ragdoll = false
	if c._torso:
		c._torso.gravity_scale = 0.0
		c._target_height = c._stand_height
