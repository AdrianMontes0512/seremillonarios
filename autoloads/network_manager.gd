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
	var input: Dictionary = {
		"type": MsgType.INPUT,
		"seq": input_seq,
		"dir": _get_input_direction(),
		"jump": Input.is_action_just_pressed("jump"),
		"grab": Input.is_action_pressed("grab"),
		"attack": Input.is_action_just_pressed("attack"),
		"dive": Input.is_action_pressed("dive")
	}
	input_seq += 1
	var host_id: int = SteamManager.get_host_id()
	SteamManager.send_packet(input, host_id, false)


# Obtiene la dirección de movimiento normalizada (plano XZ) desde el input local
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


# El host recopila el estado de todos los personajes y lo transmite a los clientes.
# Para el active ragdoll 6DOF enviamos la posición principal (torso) y el estado de
# los 6 RigidBody3D. Se envía SIEMPRE, no solo en ragdoll.
func _broadcast_game_state() -> void:
	var state: Dictionary = {
		"type": MsgType.STATE,
		"tick": Engine.get_physics_frames(),
		"players": {}
	}
	for steam_id in all_characters:
		var c: Node = all_characters[steam_id]
		state.players[str(steam_id)] = {
			"p": c.get_main_position(),
			"bodies": c.get_net_state()
		}
	SteamManager.broadcast(state, true)


# Aplica el estado autoritativo recibido del host. El cliente NUNCA es authority:
# solo muestra el estado de los cuerpos (sin reconciliación, los cuerpos están congelados).
func _apply_state(state: Dictionary) -> void:
	if not state.has("players"):
		return
	for steam_id_str in state.players:
		var steam_id: int = int(steam_id_str)
		var data: Dictionary = state.players[steam_id_str]
		var character: Node = get_character_by_steam_id(steam_id)
		if not character:
			continue
		# Aplicar las transformaciones de los 6 cuerpos recibidas del host
		if data.has("bodies"):
			character.apply_net_state(data["bodies"])


# Enruta el paquete HIT: si no está confirmado lo valida el host,
# si ya viene confirmado lo aplica como impulso/KO
func _handle_hit(data: Dictionary) -> void:
	if not data.has("confirmed"):
		# Request del cliente — solo el host valida
		if SteamManager.is_host:
			_validate_hit_request(data)
	else:
		# Confirmación del host — aplicar el golpe localmente
		_apply_confirmed_hit(data)


# El host valida el request de golpe, calcula la fuerza y hace broadcast de la confirmación.
# Usa get_main_position() (posición del torso) para medir distancias, ya que el root del
# 6DOF es estático y su global_position no representa la posición real del personaje.
func _validate_hit_request(data: Dictionary) -> void:
	if not data.has("attacker"):
		return
	var attacker_steam_id: int = int(data.attacker)
	var attacker: Node = get_character_by_steam_id(attacker_steam_id)
	if not attacker:
		return

	var attacker_pos: Vector3 = attacker.get_main_position()

	# Buscar el objetivo más cercano dentro del rango (loop simple sobre los personajes)
	var closest_node: Node = null
	var closest_steam_id: int = 0
	var closest_pos: Vector3 = Vector3.ZERO
	var closest_dist: float = HIT_RANGE
	for steam_id in all_characters:
		if steam_id == attacker_steam_id:
			continue
		var c: Node = all_characters[steam_id]
		var c_pos: Vector3 = c.get_main_position()
		var dist: float = attacker_pos.distance_to(c_pos)
		if dist <= closest_dist:
			closest_dist = dist
			closest_node = c
			closest_steam_id = steam_id
			closest_pos = c_pos

	if closest_node == null:
		return

	# Calcular la fuerza del golpe en dirección al objetivo (más impulso acumulado opcional)
	var hit_force: Vector3 = HitSystem.calculate_hit_force(
		attacker_pos,
		closest_pos,
		data.get("accumulated_impulse", Vector3.ZERO)
	)

	# Emitir confirmación autoritativa a todos los clientes
	var confirmation: Dictionary = {
		"type": MsgType.HIT,
		"confirmed": true,
		"target_id": closest_steam_id,
		"force": hit_force,
		"point": closest_pos
	}
	SteamManager.broadcast(confirmation, true)


# Aplica el golpe confirmado por el host al objetivo correspondiente
func _apply_confirmed_hit(data: Dictionary) -> void:
	if not data.has("target_id"):
		return
	var target: Node = get_character_by_steam_id(int(data.target_id))
	if target and target.has_method("receive_hit"):
		target.receive_hit(data.force, data.point)
