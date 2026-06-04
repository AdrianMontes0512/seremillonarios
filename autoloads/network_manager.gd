extends Node

# Tipos de mensajes de red
enum MsgType { INPUT = 0, STATE = 1, HIT = 2 }

# Rango máximo de golpe — debe coincidir con HitSystem.HIT_RANGE
const HIT_RANGE: float = 1.5

# Secuencia de inputs del cliente local
var input_seq: int = 0
# Cola de inputs recibidos por el host (steam_id -> datos del input)
var input_queue: Dictionary = {}
# Registro de todos los personajes en la partida (steam_id -> nodo personaje)
var all_characters: Dictionary = {}

# Umbral de error de posición para reconciliación
const POSITION_ERROR_THRESHOLD: float = 0.8
# Suavizado de interpolación para personajes remotos
const LERP_SMOOTH: float = 0.2


func _ready() -> void:
	# Conectar la señal de paquetes recibidos desde SteamManager
	SteamManager.packet_received.connect(handle_packet)
	print("NetworkManager listo")


func _physics_process(_delta: float) -> void:
	if SteamManager.is_host:
		# El host aplica los inputs acumulados y luego envía el estado autoritativo
		_apply_queued_inputs()
		_broadcast_game_state()
	else:
		# El cliente envía su input local al host
		_send_local_input()


# Registra un personaje asociado a un steam_id
func register_character(steam_id: int, character: Node) -> void:
	all_characters[steam_id] = character


# Devuelve el nodo personaje asociado al steam_id dado
func get_character_by_steam_id(steam_id: int) -> Node:
	if all_characters.has(steam_id):
		return all_characters[steam_id]
	return null


# Maneja un paquete recibido desde SteamManager
func handle_packet(data: Dictionary, from_steam_id: int) -> void:
	if not data.has("type"):
		return
	match data.type:
		MsgType.INPUT:
			# Guardar el input del cliente en la cola del host
			input_queue[from_steam_id] = data
		MsgType.STATE:
			# Aplicar el estado autoritativo recibido del host
			_apply_state(data)
		MsgType.HIT:
			# Procesar evento de golpe
			_handle_hit(data)


# Envía el input local del cliente al host
func _send_local_input() -> void:
	var my_id: int = SteamManager.my_steam_id
	var input: Dictionary = {
		"type": MsgType.INPUT,
		"seq": input_seq,
		"dir": _get_input_direction(),
		"jump": Input.is_action_just_pressed("jump"),
		"grab": Input.is_action_pressed("grab"),
		"attack": Input.is_action_just_pressed("attack")
	}
	input_seq += 1
	var host_id: int = SteamManager.get_host_id()
	SteamManager.send_packet(input, host_id, false)


# Obtiene la dirección de movimiento normalizada desde el input del jugador local
func _get_input_direction() -> Vector3:
	return Vector3(
		Input.get_axis("move_left", "move_right"),
		0.0,
		Input.get_axis("move_forward", "move_back")
	).normalized()


# El host aplica todos los inputs acumulados en la cola a los personajes correspondientes
func _apply_queued_inputs() -> void:
	for steam_id in input_queue:
		var character: Node = get_character_by_steam_id(steam_id)
		if character and character.has_method("apply_input"):
			character.apply_input(input_queue[steam_id])
	input_queue.clear()


# El host recopila el estado de todos los personajes y lo transmite a los clientes
func _broadcast_game_state() -> void:
	var state: Dictionary = {
		"type": MsgType.STATE,
		"tick": Engine.get_physics_frames(),
		"players": {}
	}
	for steam_id in all_characters:
		var c: Node = all_characters[steam_id]
		state.players[str(steam_id)] = {
			"pos": c.global_position,
			"rot": c.global_rotation,
			"vel": c.velocity,
			"ragdoll": c.is_ragdoll,
			"impulse": c.accumulated_impulse,
			"bones": _get_ragdoll_bone_state(c) if c.is_ragdoll else []
		}
	SteamManager.broadcast(state, true)


# Obtiene el estado de los huesos del ragdoll de un personaje
func _get_ragdoll_bone_state(character: Node) -> Array:
	var bones: Array = []
	if not character.has_node("Skeleton3D"):
		return bones
	for bone in character.get_node("Skeleton3D").get_children():
		if bone is PhysicalBone3D:
			bones.append({
				"name": bone.name,
				"pos": bone.global_position,
				"rot": bone.global_rotation
			})
	return bones


# Aplica el estado autoritativo recibido del host a los personajes locales
func _apply_state(state: Dictionary) -> void:
	if not state.has("players"):
		return
	for steam_id_str in state.players:
		var steam_id: int = int(steam_id_str)
		var data: Dictionary = state.players[steam_id_str]
		var character: Node = get_character_by_steam_id(steam_id)
		if not character:
			continue
		if character.is_local:
			# Reconciliar el personaje local con el estado autoritativo
			_reconcile_local(character, data)
		else:
			# Aplicar interpolación al personaje remoto
			_apply_remote(character, data)


# Reconcilia la posición del personaje local con el estado autoritativo del host
func _reconcile_local(character: Node, auth: Dictionary) -> void:
	var error: float = character.global_position.distance_to(auth.pos)
	if error > POSITION_ERROR_THRESHOLD:
		# Error grande: corrección directa
		character.global_position = auth.pos
		character.velocity = auth.vel
	elif error > 0.1:
		# Error pequeño: interpolación suave
		character.global_position = character.global_position.lerp(auth.pos, 0.3)
	# Sincronizar huesos del ragdoll si corresponde
	if auth.ragdoll and character.is_ragdoll and auth.bones.size() > 0:
		_apply_bone_state(character, auth.bones)


# Interpola la posición y rotación de un personaje remoto hacia el estado autoritativo
func _apply_remote(character: Node, auth: Dictionary) -> void:
	character.global_position = character.global_position.lerp(auth.pos, LERP_SMOOTH)
	character.global_rotation = character.global_rotation.lerp(auth.rot, LERP_SMOOTH)
	# Sincronizar estado de ragdoll si difiere
	if auth.ragdoll != character.is_ragdoll:
		if auth.ragdoll:
			character.enter_ragdoll(Vector3.ZERO, character.global_position)
		else:
			character.exit_ragdoll()


# Aplica el estado de los huesos del ragdoll al personaje
func _apply_bone_state(character: Node, bones: Array) -> void:
	if not character.has_node("Skeleton3D"):
		return
	for bone_data in bones:
		var bone: Node = character.get_node_or_null("Skeleton3D/" + bone_data.name)
		if bone:
			bone.global_position = bone_data.pos
			bone.global_rotation = bone_data.rot


# Enruta el paquete HIT: si no está confirmado lo valida el host,
# si ya viene confirmado lo aplica como ragdoll
func _handle_hit(data: Dictionary) -> void:
	if not data.has("confirmed"):
		# Request del cliente — solo el host valida
		if SteamManager.is_host:
			_validate_hit_request(data)
	else:
		# Confirmación del host — aplicar ragdoll localmente
		_apply_confirmed_hit(data)


# El host valida el request de golpe, calcula la fuerza y hace broadcast de la confirmación
func _validate_hit_request(data: Dictionary) -> void:
	if not data.has("attacker"):
		return
	var attacker_steam_id: int = int(data.attacker)
	var attacker: Node = get_character_by_steam_id(attacker_steam_id)
	if not attacker:
		return

	# Buscar el objetivo más cercano dentro del rango
	var closest: Dictionary = HitSystem.find_closest_target(
		attacker.global_position,
		all_characters,
		attacker_steam_id
	)
	if closest.is_empty():
		return

	# Calcular fuerza del golpe con el impulso acumulado del atacante
	var hit_force: Vector3 = HitSystem.calculate_hit_force(
		attacker.global_position,
		closest.node.global_position,
		data.get("accumulated_impulse", Vector3.ZERO)
	)

	# Emitir confirmación autoritativa a todos los clientes
	var confirmation: Dictionary = {
		"type": MsgType.HIT,
		"confirmed": true,
		"target_id": closest.steam_id,
		"force": hit_force,
		"point": closest.node.global_position,
	}
	SteamManager.broadcast(confirmation, true)


# Aplica el golpe confirmado por el host al objetivo correspondiente
func _apply_confirmed_hit(data: Dictionary) -> void:
	if not data.has("target_id"):
		return
	var target: Node = get_character_by_steam_id(int(data.target_id))
	if target and target.has_method("receive_hit"):
		target.receive_hit(data.force, data.point)
