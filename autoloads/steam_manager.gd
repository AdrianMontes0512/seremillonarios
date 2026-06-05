extends Node

# ============================================================
# SteamManager — funciona en dos modos:
#   - ONLINE:  GodotSteam instalado → Steam real
#   - OFFLINE: Godot normal → modo local para testing
# ============================================================

signal lobby_created(lobby_id: int)
signal lobby_joined_ok(lobby_id: int)
signal lobby_list_received(lobbies: Array)
signal peer_connected(steam_id: int)
signal packet_received(data: Dictionary, from_steam_id: int)

# Clave/valor que identifica los lobbies de este juego
const GAME_KEY: String = "game"
const GAME_VALUE: String = "seremosmillonarios"

var my_steam_id: int = 0
var lobby_id: int = 0
var is_host: bool = false
var connected_peers: Array[int] = []

var _steam_available: bool = false


func _ready() -> void:
	# Detectar si GodotSteam está instalado
	_steam_available = Engine.has_singleton("Steam")

	if not _steam_available:
		push_warning("SteamManager: GodotSteam no instalado — modo OFFLINE activado")
		# ID falso para testing local
		my_steam_id = randi_range(10000, 99999)
		print("SteamManager [OFFLINE] — Steam ID local falso: ", my_steam_id)
		return

	# GodotSteam disponible — inicializar normalmente
	var init = Steam.steamInitEx()
	if init.status != Steam.STEAM_API_INIT_RESULT_OK:
		push_error("SteamManager: Error al inicializar Steam — " + str(init))
		_steam_available = false
		my_steam_id = randi_range(10000, 99999)
		return

	my_steam_id = Steam.getSteamID()
	print("SteamManager [ONLINE] — ", Steam.getPersonaName())

	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.p2p_session_request.connect(_on_p2p_request)
	Steam.p2p_session_connect_fail.connect(_on_p2p_fail)


func _process(_delta: float) -> void:
	if not _steam_available:
		return
	Steam.run_callbacks()
	_poll_packets()


# ── Lobby ────────────────────────────────────────────────────

func create_lobby() -> void:
	is_host = true
	if not _steam_available:
		# Offline: simular lobby creado de inmediato
		lobby_id = 999999
		emit_signal("lobby_created", lobby_id)
		return
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, 4)


# Pide la lista de lobbies de este juego (solo el cliente que se une)
func request_lobby_list() -> void:
	if not _steam_available:
		# Offline: simular que existe un lobby para unirse
		emit_signal("lobby_list_received", [999999])
		return
	Steam.addRequestLobbyListStringFilter(GAME_KEY, GAME_VALUE, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()


func _on_lobby_match_list(lobbies: Array) -> void:
	print("SteamManager: lobbies encontrados — ", lobbies.size())
	emit_signal("lobby_list_received", lobbies)


func join_lobby(target_lobby_id: int) -> void:
	is_host = false
	if not _steam_available:
		lobby_id = target_lobby_id
		emit_signal("lobby_joined_ok", lobby_id)
		return
	Steam.joinLobby(target_lobby_id)


# Retorna el Steam ID del host del lobby actual
func get_host_id() -> int:
	if not _steam_available or lobby_id == 0:
		# En offline el host es siempre el jugador local
		return my_steam_id
	return Steam.getLobbyOwner(lobby_id)


func is_steam_available() -> bool:
	return _steam_available


# ── Callbacks de Steam (solo se llaman si _steam_available) ──

func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if result != Steam.RESULT_OK:
		push_error("SteamManager: Error al crear lobby — " + str(result))
		return
	lobby_id = new_lobby_id
	Steam.setLobbyData(lobby_id, GAME_KEY, GAME_VALUE)
	emit_signal("lobby_created", lobby_id)


func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		push_error("SteamManager: No se pudo unir al lobby — " + str(response))
		return
	lobby_id = joined_lobby_id
	var host_id: int = Steam.getLobbyOwner(lobby_id)
	Steam.allowP2PPacketRelay(true)
	Steam.acceptP2PSessionWithUser(host_id)
	emit_signal("lobby_joined_ok", lobby_id)
	# Pre-aceptamos la sesión con el host, así que Steam NO disparará
	# p2p_session_request en este cliente. Registramos al host como peer
	# manualmente para spawnear su personaje remoto.
	# IMPORTANTE: el host también recibe lobby_joined al crear su lobby;
	# en ese caso host_id == my_steam_id y NO debe registrarse a sí mismo
	# (si no, aparece un "peer fantasma" antes de que nadie se una).
	if host_id != my_steam_id and not connected_peers.has(host_id):
		connected_peers.append(host_id)
		emit_signal("peer_connected", host_id)


func _on_p2p_request(remote_steam_id: int) -> void:
	# Ignorar peticiones de quien no es miembro de nuestro lobby
	# (ruido de Spacewar/AppID 480 o instancias viejas) y de nosotros mismos.
	if remote_steam_id == my_steam_id or not _is_lobby_member(remote_steam_id):
		push_warning("SteamManager: P2P de no-miembro ignorado — " + str(remote_steam_id))
		return
	Steam.acceptP2PSessionWithUser(remote_steam_id)
	if not connected_peers.has(remote_steam_id):
		connected_peers.append(remote_steam_id)
		emit_signal("peer_connected", remote_steam_id)


# Verifica si un Steam ID es miembro del lobby actual
func _is_lobby_member(steam_id: int) -> bool:
	if lobby_id == 0:
		return false
	var count: int = Steam.getNumLobbyMembers(lobby_id)
	for i in count:
		if Steam.getLobbyMemberByIndex(lobby_id, i) == steam_id:
			return true
	return false


func _on_p2p_fail(remote_steam_id: int, error: int) -> void:
	push_error("SteamManager: P2P falló con " + str(remote_steam_id) + " — error: " + str(error))


# ── Envío de paquetes ─────────────────────────────────────────

func send_packet(data: Dictionary, target_steam_id: int, reliable: bool = true) -> void:
	if not _steam_available:
		return  # En offline no hay peers remotos
	var bytes: PackedByteArray = var_to_bytes(data)
	var send_type: int = Steam.P2P_SEND_RELIABLE if reliable else Steam.P2P_SEND_UNRELIABLE_NO_DELAY
	Steam.sendP2PPacket(target_steam_id, bytes, send_type, 0)


func broadcast(data: Dictionary, reliable: bool = true) -> void:
	if not _steam_available:
		return
	for peer_id: int in connected_peers:
		send_packet(data, peer_id, reliable)


func _poll_packets() -> void:
	var packet_size: int = Steam.getAvailableP2PPacketSize(0)
	while packet_size > 0:
		var packet = Steam.readP2PPacket(packet_size, 0)
		if packet and packet.has("data"):
			var data = bytes_to_var(packet.data)
			var sender: int = packet.get("remote_steam_id", 0)
			emit_signal("packet_received", data, sender)
		packet_size = Steam.getAvailableP2PPacketSize(0)
