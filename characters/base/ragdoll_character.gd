extends CharacterBody3D

# ============================================================
# Script base del personaje ragdoll
# Maneja movimiento, salto, golpes y simulación de ragdoll
# ============================================================

# --- Variables exportables ---
@export var mass: float = 70.0
@export var move_speed: float = 6.0
@export var jump_force: float = 8.0
@export var ragdoll_threshold: float = 15.0
@export var impulse_absorption: float = 0.3
@export var launch_multiplier: float = 1.0

# --- Variables de estado ---
var is_ragdoll: bool = false
var accumulated_impulse: Vector3 = Vector3.ZERO
var ragdoll_timer: float = 0.0
var player_id: int = 0
var is_local: bool = false

# --- Constantes ---
const RAGDOLL_RECOVERY_TIME: float = 1.5
const BASE_HIT_POWER: float = 12.0


func _ready() -> void:
	# Intentar asignar la masa si el CharacterBody3D expone esa propiedad
	if "mass" in self:
		self.mass = mass
	print("[RagdollCharacter] Listo. player_id=%d | is_local=%s | mass=%.1f" % [player_id, is_local, mass])


func _physics_process(delta: float) -> void:
	# Solo el jugador local procesa inputs directamente
	if not is_local:
		return

	if is_ragdoll:
		try_exit_ragdoll(delta)
		return

	handle_movement(delta)
	handle_jump()
	handle_grab()


# ============================================================
# Movimiento del personaje
# ============================================================
func handle_movement(delta: float) -> void:
	# Leer ejes de entrada horizontal
	var move_x: float = Input.get_axis("move_left", "move_right")
	var move_z: float = Input.get_axis("move_forward", "move_back")

	# Construir dirección normalizada
	var dir: Vector3 = Vector3(move_x, 0.0, move_z)
	if dir.length() > 1.0:
		dir = dir.normalized()

	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

	# Aplicar gravedad cuando no está en el suelo
	if not is_on_floor():
		velocity.y -= 9.8 * delta

	move_and_slide()


# ============================================================
# Salto
# ============================================================
func handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force


# ============================================================
# Agarrar / atacar — detecta la acción de ataque y delega
# ============================================================
func handle_grab() -> void:
	if Input.is_action_just_pressed("attack"):
		attempt_attack()


# ============================================================
# Intento de ataque con client-side prediction
# El feedback es inmediato; la confirmación del daño viene del host
# ============================================================
func attempt_attack() -> void:
	print("ATTACK ejecutado — buscando objetivo cercano")

	var attack_data: Dictionary = {
		"type": 2,  # MsgType.HIT
		"attacker": str(player_id),
		"attacker_pos": global_position,
		"attacker_vel": velocity,
		"timestamp": Time.get_ticks_msec(),
		"accumulated_impulse": accumulated_impulse,
	}

	if SteamManager.is_host:
		# El host valida su propio request directamente sin viaje de red
		if NetworkManager.has_method("_validate_hit_request"):
			NetworkManager._validate_hit_request(attack_data)
	else:
		# El cliente envía el request al host para validación autoritativa
		var host_id: int = SteamManager.get_host_id()
		SteamManager.send_packet(attack_data, host_id, true)


# ============================================================
# Entrar en modo ragdoll
# ============================================================
func enter_ragdoll(force: Vector3, point: Vector3) -> void:
	# Evitar entrar en ragdoll si ya está activo
	if is_ragdoll:
		return

	is_ragdoll = true
	ragdoll_timer = 0.0

	# Desactivar el colisionador principal para ceder el control a los huesos
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = true

	# Activar simulación física de los huesos
	if has_node("Skeleton3D"):
		$Skeleton3D.physical_bones_start_simulation()

		# Aplicar impulso al hueso torso si existe
		for child in $Skeleton3D.get_children():
			if child is PhysicalBone3D:
				# Se asume que el primer PhysicalBone3D encontrado es el torso
				child.apply_impulse(force, point - child.global_position)
				break


# ============================================================
# Intentar salir del modo ragdoll
# ============================================================
func try_exit_ragdoll(delta: float) -> void:
	if not is_ragdoll:
		return

	ragdoll_timer += delta

	# Salir solo si el tiempo de recuperación pasó y el personaje está en el suelo
	if ragdoll_timer >= RAGDOLL_RECOVERY_TIME and is_on_floor():
		exit_ragdoll()


# ============================================================
# Salir del modo ragdoll y recuperar el control
# ============================================================
func exit_ragdoll() -> void:
	is_ragdoll = false

	# Reactivar el colisionador principal
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = false

	# Detener la simulación física de los huesos
	if has_node("Skeleton3D"):
		$Skeleton3D.physical_bones_stop_simulation()

		# Reposicionar el CharacterBody3D en la posición del primer hueso físico
		for child in $Skeleton3D.get_children():
			if child is PhysicalBone3D:
				global_position = child.global_position
				break


# ============================================================
# Recibir un golpe desde otra fuente
# ============================================================
func receive_hit(force: Vector3, from_pos: Vector3) -> void:
	var total_force: Vector3 = force + accumulated_impulse

	if total_force.length() >= ragdoll_threshold:
		# La fuerza supera el umbral: activar ragdoll
		enter_ragdoll(total_force * launch_multiplier, from_pos)
		accumulated_impulse = Vector3.ZERO
	else:
		# Fuerza insuficiente: acumular como stagger
		accumulated_impulse += force * impulse_absorption
		print("[RagdollCharacter] Stagger absorbido. Impulso acumulado: ", accumulated_impulse)


# ============================================================
# Entregar un golpe a otro nodo
# ============================================================
func deliver_hit(target: Node) -> void:
	# Validar objetivo
	if target == null or target == self:
		return

	var direction: Vector3 = (target.global_position - global_position).normalized()
	var hit_force: Vector3 = direction * BASE_HIT_POWER + accumulated_impulse

	# Limpiar impulso acumulado tras usarlo
	accumulated_impulse = Vector3.ZERO

	# Enviar golpe si el objetivo lo soporta
	if target.has_method("receive_hit"):
		target.receive_hit(hit_force, global_position)


# ============================================================
# Aplicar inputs remotos (llamado por el host en multijugador)
# ============================================================
func apply_input(input: Dictionary) -> void:
	# Aplicar salto remoto
	if input.has("jump") and input["jump"]:
		velocity.y = jump_force

	# Aplicar dirección de movimiento remota
	if input.has("dir"):
		var dir: Vector3 = input["dir"]
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed

	# Placeholder para ataque remoto
	if input.has("attack") and input["attack"] and has_method("deliver_hit"):
		# TODO: determinar objetivo del ataque remoto
		pass

	move_and_slide()
