extends Node3D

# ============================================================
# Escena de prueba — flujo de 2 instancias (host / joiner)
#   - "Crear Lobby"      → eres el HOST (autoridad), spawneas en Spawn1
#   - "Buscar y Unirse"  → eres CLIENTE, spawneas en Spawn2
# El personaje remoto aparece cuando se conecta el peer.
# ============================================================

@export var character_scene: PackedScene

@onready var spawn1: Marker3D = $Spawn1
@onready var spawn2: Marker3D = $Spawn2
@onready var label_steam_id: Label = $CanvasLayer/VBoxContainer/LabelSteamID
@onready var label_latencia: Label = $CanvasLayer/VBoxContainer/LabelLatencia
@onready var label_ragdoll: Label  = $CanvasLayer/VBoxContainer/LabelRagdoll
@onready var label_impulso: Label  = $CanvasLayer/VBoxContainer/LabelImpulso

var local_character: Node = null
var remote_character: Node = null
var _menu: VBoxContainer = null


func _ready() -> void:
	label_steam_id.text = "Steam ID: " + str(SteamManager.my_steam_id)

	SteamManager.lobby_created.connect(_on_lobby_created)
	SteamManager.lobby_joined_ok.connect(_on_lobby_joined)
	SteamManager.lobby_list_received.connect(_on_lobby_list_received)
	SteamManager.peer_connected.connect(_on_peer_connected)

	_build_menu()


func _process(_delta: float) -> void:
	_update_debug_ui()


# ── Menú simple en pantalla ──────────────────────────────────
func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.position = Vector2(10, 120)
	$CanvasLayer.add_child(_menu)

	var btn_host := Button.new()
	btn_host.text = "Crear Lobby (Host)"
	btn_host.pressed.connect(_on_host_pressed)
	_menu.add_child(btn_host)

	var btn_join := Button.new()
	btn_join.text = "Buscar y Unirse"
	btn_join.pressed.connect(_on_join_pressed)
	_menu.add_child(btn_join)


func _hide_menu() -> void:
	if _menu:
		_menu.queue_free()
		_menu = null


func _on_host_pressed() -> void:
	_hide_menu()
	SteamManager.create_lobby()


func _on_join_pressed() -> void:
	_hide_menu()
	SteamManager.request_lobby_list()


# ── Callbacks de red ─────────────────────────────────────────
func _on_lobby_created(lobby_id: int) -> void:
	print("TestArena [HOST]: lobby creado — ID: ", lobby_id)
	label_steam_id.text += " | HOST lobby: " + str(lobby_id)
	# El host es autoridad y spawnea en Spawn1
	_spawn_local_character(spawn1.global_position)


func _on_lobby_list_received(lobbies: Array) -> void:
	if lobbies.is_empty():
		print("TestArena: no se encontraron lobbies. Reintenta o crea uno.")
		_build_menu()  # volver a mostrar el menú
		return
	# Unirse al primer lobby disponible
	SteamManager.join_lobby(int(lobbies[0]))


func _on_lobby_joined(lobby_id: int) -> void:
	# El host también recibe lobby_joined al crear su lobby: ignorarlo.
	if SteamManager.is_host:
		return
	print("TestArena [CLIENTE]: unido al lobby — ID: ", lobby_id)
	label_steam_id.text += " | CLIENTE lobby: " + str(lobby_id)
	# El cliente spawnea en Spawn2
	_spawn_local_character(spawn2.global_position)


func _on_peer_connected(steam_id: int) -> void:
	print("TestArena: peer conectado — Steam ID: ", steam_id)
	# El remoto va en el spawn opuesto al nuestro
	var remote_pos: Vector3 = spawn2.global_position if SteamManager.is_host else spawn1.global_position
	_spawn_remote_character(steam_id, remote_pos)


# ── Spawning ─────────────────────────────────────────────────
func _spawn_local_character(spawn_pos: Vector3) -> void:
	if character_scene == null:
		push_error("TestArena: asignar character_scene en el Inspector")
		return
	local_character = character_scene.instantiate()
	# Configurar antes de add_child para que _ready vea los valores correctos
	local_character.is_local = true
	local_character.player_id = SteamManager.my_steam_id
	add_child(local_character)
	local_character.global_position = spawn_pos
	NetworkManager.register_character(SteamManager.my_steam_id, local_character)
	print("TestArena: personaje LOCAL spawneado en ", spawn_pos)


func _spawn_remote_character(steam_id: int, spawn_pos: Vector3) -> void:
	if character_scene == null:
		return
	remote_character = character_scene.instantiate()
	remote_character.is_local = false
	remote_character.player_id = steam_id
	add_child(remote_character)
	remote_character.global_position = spawn_pos
	NetworkManager.register_character(steam_id, remote_character)
	print("TestArena: personaje REMOTO spawneado — Steam ID: ", steam_id)


# ── UI de debug ──────────────────────────────────────────────
func _update_debug_ui() -> void:
	if local_character == null:
		return
	label_ragdoll.text = "Ragdoll: " + str(local_character.is_ragdoll)
	label_impulso.text = "Impulso acum: " + str(local_character.accumulated_impulse.length()).pad_decimals(2)
	label_latencia.text = "Peers conectados: " + str(SteamManager.connected_peers.size())
