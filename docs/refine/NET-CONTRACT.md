# Contrato de integración online del Gallo 6DOF (host-autoritativo)

Modelo: **el HOST simula la física de TODOS los personajes** (su propio jugador por
Input, y el avatar de cada cliente por `apply_input`). El host transmite, cada tick,
las transformaciones de los **6 RigidBody3D** de cada personaje. Los **CLIENTES no
simulan**: congelan los cuerpos (kinematic) y aplican las transformaciones recibidas.
Cada cliente envía su input al host.

`is_authority == SteamManager.is_host` para TODOS los personajes.

## Interfaz pública de ActiveRagdollController (root de gallo_6dof.tscn)
Campos:
- `is_local: bool = false`
- `player_id: int = 0`
- `is_authority: bool = false`
- `is_ragdoll: bool = false`  (true mientras está KO)
- `accumulated_impulse: Vector3 = Vector3.ZERO`

Métodos (firmas EXACTAS — los subagentes deben respetarlas):
- `func setup_net(p_is_local: bool, p_player_id: int, p_is_authority: bool) -> void`
  Guarda los flags. Si NO es authority → llama `NET.set_client_mode(self)` (congela cuerpos).
- `func get_main_position() -> Vector3`  (posición del torso; ya existe)
- `func get_net_state() -> Array`  → `return NET.get_state(self)`
- `func apply_net_state(state: Array) -> void`  → `NET.apply_state(self, state)`
- `func apply_input(input: Dictionary) -> void`  (el host aplica input remoto)
- `func receive_hit(force: Vector3, from_pos: Vector3) -> void`  (KO/impulso)

Donde `NET` es el componente de red, cargado por preload:
`const NET := preload("res://characters/base/components/ragdoll_net_sync.gd")`
y se instancia una vez (`var _net := NET.new()`), o se usan métodos estáticos.
USAR INSTANCIA: `var _net = NET.new()` en `_ready`, y `_net.get_state(self)` etc.

Gating de simulación en `_physics_process`:
- Si `not is_authority`: **return inmediato** (el cliente solo muestra; los cuerpos
  están congelados y los maneja la red).
- Si `is_authority and is_local`: leer Input (jugador del host).
- Si `is_authority and not is_local`: usar el último input de `apply_input` (avatar
  del cliente). Guardar el input en un campo `_remote_input` y consumirlo en el tick.

## Diccionario de input (cliente→host)
Claves: `"dir": Vector3` (XZ normalizado), `"jump": bool`, `"attack": bool` (=punch),
`"grab": bool`, `"dive": bool`.

## Componente de red — ragdoll_net_sync.gd (RefCounted)
Los 6 cuerpos están en `char.torso, char.head, char.arm_l, char.arm_r, char.leg_l,
char.leg_r` (RigidBody3D). Nombres lógicos: "Torso","Head","ArmL","ArmR","LegL","LegR".
- `func bodies(char) -> Array` → los 6 RigidBody3D en orden fijo.
- `func get_state(char) -> Array`  → por cuerpo `{"n":nombre, "p":global_position,
  "r":global_rotation, "lv":linear_velocity, "av":angular_velocity}`.
- `func apply_state(char, state: Array) -> void`  → por entrada, ubicar el cuerpo por
  nombre y LERPear su `global_position`/`global_rotation` hacia el objetivo
  (factor ~0.35). Cuerpos están congelados (kinematic), así que mover transform es válido.
- `func set_client_mode(char) -> void`  → cada cuerpo: `freeze = true`,
  `freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC`. (En el host NO se llama.)

## network_manager.gd (protocolo STATE)
- `_broadcast_game_state` (host): por jugador →
  `players[str(id)] = {"p": c.get_main_position(), "bodies": c.get_net_state()}`.
  SIEMPRE (no solo en ragdoll).
- `_apply_state` (cliente): por jugador → `c.apply_net_state(data["bodies"])`.
  (El cliente nunca es authority → solo muestra; sin reconciliación de velocity.)
- `_apply_queued_inputs` (host): `c.apply_input(input_queue[id])` (sin cambios).
- `_send_local_input`: añadir `"dive": Input.is_action_pressed("dive")` y mantener
  dir/jump/attack/grab.
- HIT: usar `get_main_position()` para distancias (NO `global_position` del root, que
  es estático). Calcular el objetivo más cercano con esas posiciones.
- QUITAR dependencias de `c.velocity`, `c.enter_ragdoll/exit_ragdoll`, `Skeleton3D`.

## test_arena.gd (spawn)
- `character_scene.instantiate()`, `add_child`, `root.global_position = spawn_pos`
  (mueve todo el ragdoll), luego `character.setup_net(is_local, player_id, SteamManager.is_host)`,
  `NetworkManager.register_character(id, character)`.

## TestArena.tscn
- `character_scene` → `res://characters/gallo/gallo_6dof.tscn`.
