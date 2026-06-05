extends CharacterBody3D

# ============================================================
# Personaje ACTIVE RAGDOLL (estilo Gang Beasts) — ORQUESTADOR
# Siempre simulado como ragdoll. Delega el comportamiento en 3 componentes:
#   - RagdollBalance     (torso vertical + hover + cabeza rígida)
#   - RagdollLocomotion  (movimiento como unidad + estabilidad de piernas)
#   - RagdollCombat      (punch + knockdown + recuperación)
# Cada componente vive en su propio archivo (characters/base/components/).
# ============================================================

# --- Tuning (ajustable por personaje) ---
@export var mass: float = 70.0
@export var move_force: float = 9.0          # empuje horizontal al moverse
@export var jump_force: float = 6.0          # impulso vertical del salto
@export var balance_strength: float = 10.0   # rapidez de enderezado (rad/s por rad)
@export var hover_strength: float = 26.0     # fuerza del resorte de altura
@export var hover_damp: float = 6.0          # amortiguación vertical del hover
@export var ragdoll_threshold: float = 15.0  # fuerza de golpe para tumbarlo
@export var impulse_absorption: float = 0.3
@export var launch_multiplier: float = 1.0
@export var stun_time: float = 1.3           # segundos sin equilibrio tras un golpe

# --- Estado ---
var player_id: int = 0
var is_local: bool = false
var accumulated_impulse: Vector3 = Vector3.ZERO
var is_ragdoll: bool = false   # true = tumbado/aturdido (sin control de equilibrio)

# --- Referencias internas ---
var _skel: Skeleton3D = null
var _torso: PhysicalBone3D = null
var _target_height: float = 0.0
var _stand_height: float = 0.0
var _stun: float = 0.0

# --- Componentes (preload para no depender del cache de class_name) ---
const _BalanceScript := preload("res://characters/base/components/ragdoll_balance.gd")
const _LocomotionScript := preload("res://characters/base/components/ragdoll_locomotion.gd")
const _CombatScript := preload("res://characters/base/components/ragdoll_combat.gd")
var _balance = null
var _locomotion = null
var _combat = null

const BASE_HIT_POWER: float = 12.0
const GRAVITY: float = 9.8
const MAX_RIGHT_SPEED: float = 9.0   # tope de velocidad angular de enderezado (rad/s)


func _ready() -> void:
	_skel = get_node_or_null("Skeleton3D")
	# La cápsula de caminar ya no se usa: todo el movimiento es físico (ragdoll).
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = true

	setup_bone_collision_layers()

	if _skel:
		_torso = bone("torso")
		_skel.physical_bones_start_simulation()
		_setup_bone_physics()
		await get_tree().physics_frame
		if _torso:
			_target_height = _torso.global_position.y
			_stand_height = _target_height

	_balance = _BalanceScript.new()
	_locomotion = _LocomotionScript.new()
	_combat = _CombatScript.new()

	print("[RagdollCharacter] Active ragdoll listo. player_id=%d | is_local=%s" % [player_id, is_local])


# Devuelve el PhysicalBone3D por nombre (torso, head, arm_l, arm_r, leg_l, leg_r).
func bone(n: String) -> PhysicalBone3D:
	if _skel == null:
		return null
	return _skel.get_node_or_null(n) as PhysicalBone3D


# Capa 2 = huesos del ragdoll; máscara a la capa 1 = mundo/piso.
func setup_bone_collision_layers() -> void:
	if _skel == null:
		return
	for child in _skel.get_children():
		if child is PhysicalBone3D:
			child.collision_layer = 2
			child.collision_mask = 1


# Física base de huesos. El torso flota (sin gravedad) y lo sostiene el hover;
# el resto cuelga con gravedad. (Los JOINTS los configura tools/build_gallo_ragdoll.gd)
func _setup_bone_physics() -> void:
	for c in _skel.get_children():
		if c is PhysicalBone3D:
			c.linear_damp = 0.5
			c.angular_damp = 1.0
	if _torso:
		_torso.gravity_scale = 0.0
		_torso.linear_damp = 0.7   # bajo: el hover puede levantarlo rápido
		_torso.angular_damp = 6.0


func _physics_process(delta: float) -> void:
	if _torso == null:
		return

	# Aturdido tras un golpe: cae como trapo y luego se levanta solo.
	if _stun > 0.0:
		_combat.tick_stunned(self, delta)
		return

	# Orden de escritura sobre el torso: balance -> locomoción -> combate.
	_balance.tick(self, delta)
	if is_local:
		_locomotion.tick(self, delta)
	_combat.tick(self, delta)


# ============================================================
# Entradas de red / combate (delegan en los componentes)
# ============================================================
func receive_hit(force: Vector3, _from_pos: Vector3) -> void:
	var total_force: Vector3 = force + accumulated_impulse
	if total_force.length() >= ragdoll_threshold:
		accumulated_impulse = Vector3.ZERO
		_combat.knock_down(self, total_force * launch_multiplier)
	else:
		accumulated_impulse += force * impulse_absorption


# Atajo para tests / disparos directos.
func knock_down(impulse: Vector3) -> void:
	_combat.knock_down(self, impulse)


func attempt_attack() -> void:
	if _combat:
		_combat.punch(self)
	var attack_data: Dictionary = {
		"type": 2,  # MsgType.HIT
		"attacker": str(player_id),
		"attacker_pos": get_main_position(),
		"attacker_vel": _torso.linear_velocity if _torso else Vector3.ZERO,
		"timestamp": Time.get_ticks_msec(),
		"accumulated_impulse": accumulated_impulse,
	}
	if SteamManager.is_host:
		if NetworkManager.has_method("_validate_hit_request"):
			NetworkManager._validate_hit_request(attack_data)
	else:
		var host_id: int = SteamManager.get_host_id()
		SteamManager.send_packet(attack_data, host_id, true)


func deliver_hit(target: Node) -> void:
	if target == null or target == self:
		return
	var direction: Vector3 = (target.get_main_position() - get_main_position()).normalized()
	var hit_force: Vector3 = direction * BASE_HIT_POWER + accumulated_impulse
	accumulated_impulse = Vector3.ZERO
	if target.has_method("receive_hit"):
		target.receive_hit(hit_force, get_main_position())


# Posición "real" del personaje = la del torso físico (no del nodo raíz).
func get_main_position() -> Vector3:
	return _torso.global_position if _torso else global_position


# Input remoto (el host aplica los inputs del cliente).
func apply_input(input: Dictionary) -> void:
	if _locomotion:
		_locomotion.apply_remote(self, input)
