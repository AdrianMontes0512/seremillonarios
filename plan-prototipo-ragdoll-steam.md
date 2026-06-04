# Plan de Implementación — Prototipo Ragdoll + Steam Multiplayer

## Objetivo del prototipo

> **Dos personajes con física ragdoll sincronizados online entre dos clientes, con golpes que se sienten responsivos.**

Si esto funciona, el resto del juego es construible. Este documento es la hoja de ruta para llegar a ese milestone.

---

## Resumen de fases

| Fase | Qué construir | Criterio de éxito |
|---|---|---|
| 0 | Setup del proyecto | Godot + GodotSteam inicializan sin errores |
| 1 | Personaje ragdoll base | Un personaje local con ragdoll funcional |
| 2 | Física de los 4 personajes | Cada animal se comporta diferente al recibir golpes |
| 3 | Steam lobbies y conexión P2P | Dos instancias conectadas vía Steam |
| 4 | Sincronización host-authority | Los dos personajes se ven en ambas pantallas |
| 5 | Sistema de golpes responsivos | Golpe en A → ragdoll en B en menos de 150ms percibidos |

---

## Fase 0 — Setup del proyecto

### 0.1 Godot 4.3+ con Jolt Physics

Jolt viene integrado desde Godot 4.2. Hay que activarlo y configurarlo para determinismo desde el inicio — no se puede agregar después sin romper la sincronización.

En `Project Settings`:
```
Physics > 3D > Physics Engine          → JoltPhysics3D
Physics > Common > Physics Ticks Per Second → 60
Physics > Common > Max Physics Steps Per Frame → 8
```

En `Project Settings > General` agregar manualmente:
```
physics/jolt_3d/simulation/use_enhanced_internal_edge_removal = true
```

### 0.2 GodotSteam

Usar la versión pre-compilada que coincida con tu versión de Godot exacta — no compilar desde fuente todavía.

1. Descargar de https://godotsteam.com — sección "Pre-Compiled"
2. Reemplazar el ejecutable de Godot con la versión GodotSteam
3. Copiar la carpeta `addons/godotsteam` al proyecto
4. Crear `steam_appid.txt` en la raíz del proyecto con el contenido: `480` (App ID de Spacewar — sirve para desarrollo sin App ID propio)
5. Activar el plugin en `Project Settings > Plugins`

### 0.3 Autoloads

Crear en `Project Settings > Autoload` en este orden:
```
res://autoloads/steam_manager.gd   → nombre: SteamManager
res://autoloads/network_manager.gd → nombre: NetworkManager
```

### 0.4 Estructura de carpetas

```
res://
├── autoloads/
│   ├── steam_manager.gd
│   └── network_manager.gd
├── characters/
│   ├── base/
│   │   ├── ragdoll_character.tscn
│   │   └── ragdoll_character.gd
│   ├── gallo/
│   │   ├── gallo.tscn          ← extiende ragdoll_character.tscn
│   │   └── gallo.gd
│   ├── caballo/
│   │   ├── caballo.tscn
│   │   └── caballo.gd
│   ├── mapache/
│   │   ├── mapache.tscn
│   │   └── mapache.gd
│   └── gato/
│       ├── gato.tscn
│       └── gato.gd
├── scenes/
│   └── test_arena.tscn
└── main.tscn
```

### Criterio de éxito — Fase 0
- `SteamManager._ready()` imprime el nombre de usuario de Steam sin errores
- El proyecto corre a 60 physics FPS estables con Jolt activo

---

## Fase 1 — Personaje ragdoll base

Un único personaje que funcione bien en local. Sin diferencias por animal todavía — eso es Fase 2.

### 1.1 Estructura de la escena base

```
RagdollCharacter (CharacterBody3D)        ← controller de movimiento e inputs
├── CollisionShape3D (CapsuleShape3D)     ← colisión para modo kinematic
├── MeshInstance3D                         ← visual temporal (cápsula de color)
├── Skeleton3D
│   ├── BoneAttachment3D (torso)
│   │   └── PhysicalBone3D
│   ├── BoneAttachment3D (cabeza)
│   │   └── PhysicalBone3D
│   ├── BoneAttachment3D (brazo_izq)
│   │   └── PhysicalBone3D
│   ├── BoneAttachment3D (brazo_der)
│   │   └── PhysicalBone3D
│   ├── BoneAttachment3D (pierna_izq)
│   │   └── PhysicalBone3D
│   └── BoneAttachment3D (pierna_der)
│       └── PhysicalBone3D
└── RayCast3D (suelo_check)               ← para detectar is_on_floor()
```

### 1.2 Variables de configuración del personaje base

Estas variables son las que cada personaje animal va a sobrescribir en Fase 2:

```gdscript
# ragdoll_character.gd

# Física — valores base, cada animal los sobreescribe
@export var mass: float = 70.0
@export var move_speed: float = 6.0
@export var jump_force: float = 8.0
@export var ragdoll_threshold: float = 15.0   # fuerza mínima para activar ragdoll
@export var impulse_absorption: float = 0.3    # qué porcentaje del golpe se acumula
@export var launch_multiplier: float = 1.0     # cuánto vuela al recibir un golpe

# Estado
var is_ragdoll: bool = false
var accumulated_impulse: Vector3 = Vector3.ZERO
var ragdoll_timer: float = 0.0
const RAGDOLL_RECOVERY_TIME: float = 1.5      # segundos antes de poder recuperarse

# Red
var player_id: int = 0         # Steam ID del jugador que controla este personaje
var is_local: bool = false      # true solo para el personaje que controla este cliente
```

### 1.3 Sistema de dos modos: kinematic ↔ ragdoll

El personaje alterna entre control normal y física pura:

```gdscript
func enter_ragdoll(force: Vector3, point: Vector3):
    if is_ragdoll:
        return
    is_ragdoll = true
    ragdoll_timer = 0.0
    $CollisionShape3D.disabled = true
    $Skeleton3D.physical_bones_start_simulation()
    # Aplicar la fuerza al hueso del torso — centro de masa
    var torso_bone = $Skeleton3D.get_node("PhysicalBone3D_torso")
    torso_bone.apply_impulse(force, point - torso_bone.global_position)

func try_exit_ragdoll(delta: float):
    if not is_ragdoll:
        return
    ragdoll_timer += delta
    if ragdoll_timer >= RAGDOLL_RECOVERY_TIME and is_on_floor():
        exit_ragdoll()

func exit_ragdoll():
    is_ragdoll = false
    $CollisionShape3D.disabled = false
    $Skeleton3D.physical_bones_stop_simulation()
    # Mover el CharacterBody3D a donde quedó el ragdoll
    var torso_pos = $Skeleton3D.get_node("PhysicalBone3D_torso").global_position
    global_position = torso_pos
```

### 1.4 Controles locales

Solo los 3 verbos del GDD: correr, saltar, agarrar.

```gdscript
func _physics_process(delta: float):
    if not is_local:
        return   # los personajes remotos no procesan input
    if is_ragdoll:
        try_exit_ragdoll(delta)
        return

    handle_movement(delta)
    handle_jump()
    handle_grab()

func handle_movement(delta: float):
    var dir = Vector3(
        Input.get_axis("move_left", "move_right"),
        0,
        Input.get_axis("move_forward", "move_back")
    ).normalized()
    velocity.x = dir.x * move_speed
    velocity.z = dir.z * move_speed
    velocity.y -= 9.8 * delta   # gravedad manual
    move_and_slide()
```

### 1.5 Sistema de golpes con impulso acumulado

Implementación directa de la mecánica del GDD:

```gdscript
func receive_hit(force: Vector3, from_pos: Vector3):
    # Acumular impulso si el golpe no tumba al personaje
    var total_force = force + accumulated_impulse

    if total_force.length() >= ragdoll_threshold:
        enter_ragdoll(total_force * launch_multiplier, from_pos)
        accumulated_impulse = Vector3.ZERO
    else:
        # Absorber parte del golpe — el personaje se tambalea pero no cae
        accumulated_impulse += force * impulse_absorption
        play_stagger_animation()

func deliver_hit(target: RagdollCharacter):
    if target == null or target == self:
        return
    var direction = (target.global_position - global_position).normalized()
    var hit_force = direction * BASE_HIT_POWER
    # El impulso acumulado se suma al próximo golpe que demos
    hit_force += accumulated_impulse
    accumulated_impulse = Vector3.ZERO
    target.receive_hit(hit_force, global_position)
```

### Criterio de éxito — Fase 1
- El personaje camina, salta y puede agarrar superficies
- Un golpe activa el ragdoll y se ve natural con Jolt
- El personaje se recupera solo después de 1.5 segundos en el suelo
- El impulso acumulado se nota: el personaje más golpeado pega más fuerte

---

## Fase 2 — Física de los 4 personajes

Cada animal sobreescribe las variables base de `ragdoll_character.gd`. Las diferencias son puramente numéricas y de comportamiento ragdoll — sin stats en pantalla.

### Gallo (rojo) — difícil de derribar, combate directo

Centro de masa bajo → necesita más fuerza para activar ragdoll. El referente del combate cuerpo a cuerpo.

```gdscript
# gallo.gd extends RagdollCharacter
func _ready():
    super._ready()
    mass = 75.0
    move_speed = 6.0
    jump_force = 7.5
    ragdoll_threshold = 20.0    # necesita MÁS fuerza para caer
    impulse_absorption = 0.4    # absorbe más impulso antes de caer
    launch_multiplier = 0.7     # vuela MENOS lejos cuando cae
    # El centro de masa bajo se implementa bajando el centro de la cápsula
    $CollisionShape3D.position.y = -0.2
```

### Caballo (azul) — el más grande, más daño al caer

Masa alta, alcance largo por extremidades. Lento pero devastador.

```gdscript
# caballo.gd extends RagdollCharacter
func _ready():
    super._ready()
    mass = 110.0
    move_speed = 4.5            # el más lento
    jump_force = 6.0
    ragdoll_threshold = 25.0    # muy difícil de tumbar
    impulse_absorption = 0.2
    launch_multiplier = 0.5     # casi no vuela
    # Alcance extra al agarrar — se implementa con un Area3D más grande
    $GrabArea.scale = Vector3(1.4, 1.0, 1.4)
    # Más daño al caer encima de alguien
    fall_damage_multiplier = 2.0
```

### Mapache (verde) — pequeño, ligero, escapa por física

El opuesto del Caballo. Vuela mucho, difícil de agarrar.

```gdscript
# mapache.gd extends RagdollCharacter
func _ready():
    super._ready()
    mass = 45.0
    move_speed = 8.5            # el más rápido
    jump_force = 10.0           # salta más alto
    ragdoll_threshold = 8.0     # cae con muy poco golpe
    impulse_absorption = 0.1    # casi no acumula impulso
    launch_multiplier = 2.0     # vuela EL DOBLE de lejos
    # Hitbox más pequeña — más difícil de agarrar
    $CollisionShape3D.shape.radius = 0.3
    $CollisionShape3D.shape.height = 1.4
```

### Gato (morado) — deformable, impredecible, extremidades flexibles

Las articulaciones tienen más libertad de movimiento que los otros. Sus agarres crean conexiones físicas inesperadas.

```gdscript
# gato.gd extends RagdollCharacter
func _ready():
    super._ready()
    mass = 60.0
    move_speed = 7.0
    jump_force = 9.0
    ragdoll_threshold = 12.0
    impulse_absorption = 0.35
    launch_multiplier = 1.3
    # Articulaciones más sueltas — configurar los PhysicalBone3D con más angular freedom
    configure_flexible_joints()

func configure_flexible_joints():
    # Aumentar el rango de movimiento de cada PhysicalBone3D
    for bone in $Skeleton3D.get_children():
        if bone is PhysicalBone3D:
            bone.joint_type = PhysicalBone3D.JOINT_TYPE_CONE_TWIST
            # Los valores exactos se ajustan en el editor por visión
```

### Criterio de éxito — Fase 2
- Probar con el mismo golpe en los 4 personajes — el Caballo casi no se mueve, el Mapache vuela el doble
- El Gato en ragdoll se ve más flexible y raro que los demás
- Las diferencias son visibles inmediatamente, sin leer ningún stat

---

## Fase 3 — Steam lobbies y conexión P2P

### 3.1 SteamManager

```gdscript
# autoloads/steam_manager.gd
extends Node

signal lobby_created(lobby_id: int)
signal lobby_joined_ok(lobby_id: int)
signal peer_connected(steam_id: int)
signal packet_received(data: Dictionary, from_steam_id: int)

var my_steam_id: int = 0
var lobby_id: int = 0
var is_host: bool = false
var connected_peers: Array[int] = []   # Steam IDs de los otros jugadores

func _ready():
    var init = Steam.steamInitEx()
    if init.status != Steam.STEAM_API_INIT_RESULT_OK:
        push_error("Steam no inicializó: " + str(init))
        return
    my_steam_id = Steam.getSteamID()
    print("Steam OK — usuario: ", Steam.getPersonaName())

    # Conectar señales de Steam
    Steam.lobby_created.connect(_on_lobby_created)
    Steam.lobby_joined.connect(_on_lobby_joined)
    Steam.lobby_match_list.connect(_on_lobby_list)
    Steam.p2p_session_request.connect(_on_p2p_request)
    Steam.p2p_session_connect_fail.connect(_on_p2p_fail)

func _process(_delta):
    Steam.run_callbacks()
    _poll_packets()

# --- Crear lobby ---
func create_lobby():
    is_host = true
    Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, 4)

func _on_lobby_created(result: int, new_lobby_id: int):
    if result != Steam.RESULT_OK:
        push_error("Error creando lobby: " + str(result))
        return
    lobby_id = new_lobby_id
    Steam.setLobbyData(lobby_id, "game", "seremosmillonarios")
    emit_signal("lobby_created", lobby_id)

# --- Unirse a lobby ---
func join_lobby(target_lobby_id: int):
    is_host = false
    Steam.joinLobby(target_lobby_id)

func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int):
    if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
        push_error("No se pudo unir al lobby")
        return
    lobby_id = joined_lobby_id
    # Pedir sesión P2P con el host
    var host_id = Steam.getLobbyOwner(lobby_id)
    Steam.allowP2PPacketRelay(true)
    Steam.acceptP2PSessionWithUser(host_id)
    emit_signal("lobby_joined_ok", lobby_id)

# --- P2P ---
func _on_p2p_request(remote_steam_id: int):
    Steam.acceptP2PSessionWithUser(remote_steam_id)
    if not connected_peers.has(remote_steam_id):
        connected_peers.append(remote_steam_id)
        emit_signal("peer_connected", remote_steam_id)

func _on_p2p_fail(remote_steam_id: int, error: int):
    push_error("P2P falló con " + str(remote_steam_id) + " — error: " + str(error))

func send_packet(data: Dictionary, target_steam_id: int, reliable: bool = true):
    var bytes = var_to_bytes(data)
    var send_type = Steam.P2P_SEND_RELIABLE if reliable else Steam.P2P_SEND_UNRELIABLE_NO_DELAY
    Steam.sendP2PPacket(target_steam_id, bytes, send_type, 0)

func broadcast(data: Dictionary, reliable: bool = true):
    for peer_id in connected_peers:
        send_packet(data, peer_id, reliable)

func _poll_packets():
    var packet_size = Steam.getAvailableP2PPacketSize(0)
    while packet_size > 0:
        var packet = Steam.readP2PPacket(packet_size, 0)
        if packet and packet.has("data"):
            var data = bytes_to_var(packet.data)
            emit_signal("packet_received", data, packet.steam_id_remote)
        packet_size = Steam.getAvailableP2PPacketSize(0)
```

### 3.2 UI mínima para el prototipo

```
MainMenu (Control)
├── VBoxContainer
│   ├── Label "Steam: [nombre de usuario]"
│   ├── Button "Crear Lobby"       → SteamManager.create_lobby()
│   ├── Button "Buscar Lobbies"    → Steam.requestLobbyList()
│   └── ItemList (lista de lobbies encontrados)
```

No hace falta más interfaz para el prototipo — solo lo suficiente para conectar dos instancias.

### Criterio de éxito — Fase 3
- Instancia A crea lobby y ve su propio nombre en Steam
- Instancia B encuentra el lobby y se une
- `SteamManager.connected_peers` tiene un elemento en cada instancia
- Un `send_packet` en A llega como señal `packet_received` en B

---

## Fase 4 — Sincronización host-authority

La arquitectura es la que define el GDD: el host simula de forma autoritativa, los clientes predicen localmente y reconcilian.

### 4.1 Tipos de mensaje

```gdscript
# autoloads/network_manager.gd
enum MsgType {
    INPUT    = 0,   # cliente → host    — no reliable (se puede perder)
    STATE    = 1,   # host → clientes   — reliable
    HIT      = 2,   # host → clientes   — reliable (autorización de golpe)
}
```

### 4.2 El host: recibir inputs y emitir estado

```gdscript
# En el host, cada physics frame:
func _physics_process(_delta):
    if not SteamManager.is_host:
        return
    _apply_queued_inputs()
    _broadcast_game_state()

var input_queue: Dictionary = {}   # steam_id → ultimo input recibido

func handle_packet(data: Dictionary, from_id: int):
    if data.type == MsgType.INPUT:
        input_queue[from_id] = data

func _apply_queued_inputs():
    for steam_id in input_queue:
        var input = input_queue[steam_id]
        var character = get_character_by_steam_id(steam_id)
        if character:
            character.apply_input(input)

func _broadcast_game_state():
    var state = {
        "type": MsgType.STATE,
        "tick": Engine.get_physics_frames(),
        "players": {}
    }
    for steam_id in all_characters:
        var c = all_characters[steam_id]
        state.players[str(steam_id)] = {
            "pos": c.global_position,
            "rot": c.global_rotation,
            "vel": c.velocity,
            "ragdoll": c.is_ragdoll,
            "impulse": c.accumulated_impulse,
            "bones": _get_ragdoll_state(c) if c.is_ragdoll else []
        }
    SteamManager.broadcast(state, true)

func _get_ragdoll_state(character: RagdollCharacter) -> Array:
    var bones = []
    for bone in character.get_node("Skeleton3D").get_children():
        if bone is PhysicalBone3D:
            bones.append({
                "name": bone.name,
                "pos": bone.global_position,
                "rot": bone.global_rotation,
            })
    return bones
```

### 4.3 El cliente: recibir estado y reconciliar

```gdscript
func handle_packet(data: Dictionary, from_id: int):
    if data.type == MsgType.STATE:
        _apply_state(data)

func _apply_state(state: Dictionary):
    for steam_id_str in state.players:
        var steam_id = int(steam_id_str)
        var player_data = state.players[steam_id_str]
        var character = get_character_by_steam_id(steam_id)
        if not character:
            continue

        if character.is_local:
            _reconcile_local(character, player_data)
        else:
            _apply_remote(character, player_data)

func _reconcile_local(character: RagdollCharacter, authoritative: Dictionary):
    var pos_error = character.global_position.distance_to(authoritative.pos)
    # Si el error es grande, snap. Si es pequeño, lerp suave.
    if pos_error > 0.8:
        character.global_position = authoritative.pos
        character.velocity = authoritative.vel
    elif pos_error > 0.1:
        character.global_position = character.global_position.lerp(authoritative.pos, 0.3)

    # En ragdoll: el host es siempre la autoridad sobre los huesos
    if authoritative.ragdoll and character.is_ragdoll:
        _apply_bone_state(character, authoritative.bones)

func _apply_remote(character: RagdollCharacter, authoritative: Dictionary):
    # Para personajes remotos: aplicar directo con interpolación suave
    character.global_position = character.global_position.lerp(authoritative.pos, 0.2)
    character.global_rotation = character.global_rotation.lerp(authoritative.rot, 0.2)
    if authoritative.ragdoll != character.is_ragdoll:
        if authoritative.ragdoll:
            character.enter_ragdoll(Vector3.ZERO, character.global_position)
        else:
            character.exit_ragdoll()
```

### 4.4 El cliente: enviar inputs

```gdscript
var input_seq: int = 0

func _physics_process(_delta):
    if SteamManager.is_host:
        return
    var input = {
        "type": MsgType.INPUT,
        "seq": input_seq,
        "dir": _get_input_direction(),
        "jump": Input.is_action_just_pressed("jump"),
        "grab": Input.is_action_pressed("grab"),
        "attack": Input.is_action_just_pressed("attack"),
    }
    input_seq += 1
    var host_id = Steam.getLobbyOwner(SteamManager.lobby_id)
    SteamManager.send_packet(input, host_id, false)   # unreliable — no importa perder uno
```

### Criterio de éxito — Fase 4
- Ambas instancias ven los dos personajes en pantalla
- El movimiento del personaje remoto se ve fluido (no teleporta)
- Si hay desconexión temporal y se reconecta, el error de posición se corrige visualmente

---

## Fase 5 — Golpes responsivos

El problema: el golpe ocurre en el cliente, pero el ragdoll tiene que ser autorizado por el host. La latencia hace que se sienta lento si no se maneja bien.

**Solución: client-side prediction + confirmación del host**

### 5.1 Flujo de un golpe

```
Cliente A presiona attack
    ↓
A reproduce animación de golpe localmente (inmediato)
    ↓
A envía HIT_REQUEST al host con timestamp y posición
    ↓
Host recibe, valida (¿estaban cerca hace N frames?)
    ↓
Host envía HIT_CONFIRMED a todos los clientes
    ↓
Todos aplican ragdoll al personaje golpeado
```

### 5.2 Implementación

```gdscript
# En el cliente — attack local inmediato
func attempt_attack():
    play_attack_animation()   # feedback visual inmediato sin esperar red
    var hit_request = {
        "type": MsgType.HIT,
        "attacker": SteamManager.my_steam_id,
        "attacker_pos": global_position,
        "attacker_vel": velocity,
        "timestamp": Time.get_ticks_msec(),
        "accumulated_impulse": accumulated_impulse,
    }
    var host_id = Steam.getLobbyOwner(SteamManager.lobby_id)
    SteamManager.send_packet(hit_request, host_id, true)

# En el host — validar y confirmar
func validate_hit(data: Dictionary, from_id: int):
    var latency_ms = Time.get_ticks_msec() - data.timestamp
    var attacker = get_character_by_steam_id(data.attacker)

    # Buscar el personaje más cercano al atacante
    var closest = _find_closest_target(attacker, HIT_RANGE)
    if closest == null:
        return   # no había nadie — rechazar el golpe silenciosamente

    # Calcular la fuerza del golpe
    var direction = (closest.global_position - attacker.global_position).normalized()
    var hit_force = direction * BASE_HIT_POWER + data.accumulated_impulse

    # Confirmar a todos
    var confirmation = {
        "type": MsgType.HIT,
        "confirmed": true,
        "target": _get_steam_id_of(closest),
        "force": hit_force,
        "point": closest.global_position,
    }
    SteamManager.broadcast(confirmation, true)

# En todos los clientes — aplicar ragdoll confirmado
func handle_hit_confirmed(data: Dictionary):
    var target = get_character_by_steam_id(data.target)
    if target:
        target.receive_hit(data.force, data.point)
```

### Criterio de éxito — Fase 5
- Golpe en pantalla A → ragdoll en pantalla B en menos de 150ms percibidos
- El personaje que recibió más golpes pega más fuerte en el siguiente ataque
- En conexiones con 80-100ms de latencia, los golpes se sienten responsivos

---

## Escena de prueba

Una arena plana mínima para testear todo sin distracciones visuales.

```
TestArena
├── WorldEnvironment (cielo neutro gris)
├── DirectionalLight3D
├── StaticBody3D "suelo"
│   └── CollisionShape3D (BoxShape3D, 30x1x30)
├── MeshInstance3D "suelo_visual" (material sólido gris)
├── Marker3D "spawn_1" (posición -3, 1, 0)
├── Marker3D "spawn_2" (posición  3, 1, 0)
└── CanvasLayer "debug_ui"
    ├── Label "steam_id"
    ├── Label "latencia_ms"
    ├── Label "pos_error"       ← diferencia local vs autoritativa
    ├── Label "ragdoll_state"
    └── Label "impulso_acum"
```

---

## Orden de implementación recomendado

Cada punto debe funcionar antes de pasar al siguiente.

1. Godot + Jolt configurado → Steam inicializa → ver nombre de usuario en consola
2. Personaje base con movimiento kinematic en local
3. Ragdoll activa y desactiva correctamente con Jolt en local
4. Sistema de golpes con impulso acumulado en local (sin red)
5. Los 4 personajes con sus diferencias físicas verificadas en local
6. Lobby de Steam: crear y unirse desde dos instancias
7. P2P conectado: send/receive de un paquete de prueba simple
8. Movimiento sincronizado: ver el personaje remoto moverse
9. Ragdoll sincronizado: golpe en A → ragdoll en B
10. Golpes responsivos: latencia percibida < 150ms en conexión normal

---

## Valores a ajustar en playtesting

Estos números son punto de partida — van a cambiar con pruebas reales:

| Variable | Valor inicial | Qué cambia si sube |
|---|---|---|
| `ragdoll_threshold` base | 15.0 | Más difícil de tumbar |
| `BASE_HIT_POWER` | 12.0 | Golpes mandan más lejos |
| `RAGDOLL_RECOVERY_TIME` | 1.5s | Más tiempo en el suelo |
| `impulse_absorption` | 0.3 | Más impulso acumulado |
| `HIT_RANGE` (detección) | 1.5m | Rango de golpe más grande |
| Umbral de reconciliación | 0.8m | Más tolerante al desync |
| Interpolación remota | 0.2 | Más suave pero más lag visual |

---

*Plan en desarrollo — actualizar con resultados de cada fase.*
