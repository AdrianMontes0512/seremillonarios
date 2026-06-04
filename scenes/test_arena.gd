extends Node3D

# ============================================================
# Escena de prueba — conecta personajes, Steam y red
# ============================================================

# Cambiar esta variable para probar distintos personajes
@export var character_scene: PackedScene

@onready var spawn1: Marker3D = $Spawn1
@onready var spawn2: Marker3D = $Spawn2
@onready var label_steam_id: Label  = $CanvasLayer/VBoxContainer/LabelSteamID
@onready var label_latencia: Label  = $CanvasLayer/VBoxContainer/LabelLatencia
@onready var label_ragdoll: Label   = $CanvasLayer/VBoxContainer/LabelRagdoll
@onready var label_impulso: Label   = $CanvasLayer/VBoxContainer/LabelImpulso

var local_character: Node = null
var remote_character: Node = null


func _ready() -> void:
	# Mostrar Steam ID local
	label_steam_id.text = "Steam ID: " + str(SteamManager.my_steam_id)

	# Conectar señales de Steam
	SteamManager.lobby_created.connect(_on_lobby_created)
	SteamManager.lobby_joined_ok.connect(_on_lobby_joined)
	SteamManager.peer_connected.connect(_on_peer_connected)

	# Crear lobby automáticamente al abrir la escena
	# Para el segundo cliente: comentar esta línea y descomentar join_lobby()
	SteamManager.create_lobby()
	# SteamManager.join_lobby(LOBBY_ID_AQUI)  # ← el segundo cliente usa esta línea


func _process(_delta: float) -> void:
	_update_debug_ui()


func _update_debug_ui() -> void:
	if local_character == null:
		return
	label_ragdoll.text = "Ragdoll: " + str(local_character.is_ragdoll)
	label_impulso.text = "Impulso acum: " + str(local_character.accumulated_impulse.length()).pad_decimals(2)
	# Latencia: aproximación — en el futuro usar timestamp de los paquetes STATE
	label_latencia.text = "Peers conectados: " + str(SteamManager.connected_peers.size())


func _on_lobby_created(lobby_id: int) -> void:
	print("TestArena: lobby creado — ID: ", lobby_id)
	label_steam_id.text += " | Lobby: " + str(lobby_id)
	# Instanciar el personaje local en spawn1
	_spawn_local_character(spawn1.global_position)


func _on_lobby_joined(lobby_id: int) -> void:
	print("TestArena: lobby unido — ID: ", lobby_id)
	label_steam_id.text += " | En lobby: " + str(lobby_id)
	# El cliente que se une spawnea en spawn2
	_spawn_local_character(spawn2.global_position)


func _on_peer_connected(steam_id: int) -> void:
	print("TestArena: peer conectado — Steam ID: ", steam_id)
	# Instanciar el personaje remoto (no es local, no procesa inputs)
	_spawn_remote_character(steam_id, spawn1.global_position)


func _spawn_local_character(spawn_pos: Vector3) -> void:
	if character_scene == null:
		push_error("TestArena: asignar character_scene en el Inspector")
		return

	local_character = character_scene.instantiate()
	add_child(local_character)
	local_character.global_position = spawn_pos
	local_character.is_local = true
	local_character.player_id = SteamManager.my_steam_id

	# Registrar en el NetworkManager
	NetworkManager.register_character(SteamManager.my_steam_id, local_character)
	print("TestArena: personaje local spawneado en ", spawn_pos)


func _spawn_remote_character(steam_id: int, spawn_pos: Vector3) -> void:
	if character_scene == null:
		return

	remote_character = character_scene.instantiate()
	add_child(remote_character)
	remote_character.global_position = spawn_pos
	remote_character.is_local = false
	remote_character.player_id = steam_id

	# Registrar en el NetworkManager
	NetworkManager.register_character(steam_id, remote_character)
	print("TestArena: personaje remoto spawneado — Steam ID: ", steam_id)
