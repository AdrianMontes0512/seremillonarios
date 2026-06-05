# Plan de refinamiento del active ragdoll (Gallo)

_2026-06-05_

## Problemas reportados (feel actual)
1. **Cabeza** se mueve sin sentido → debería ir casi rígida con el torso.
2. **Brazos** aceptables (ajuste menor, que no se desprendan/flaileen feo).
3. **Movimiento raro**: el torso avanza y **las piernas se arrastran** detrás
   (no acompañan al cuerpo) → se siente desconectado.
4. **Piernas inestables / se abren** (splay) al moverse y al recuperarse.
5. Falta **animación de golpear** (punch) — procedural, no hay clips.

## Estrategia de paralelización
El controlador hoy es un solo archivo (`ragdoll_character.gd`) → si varios subagentes
lo editan, conflicto. Solución: **refactor a componentes**, un archivo por concern.
Cada subagente es dueño de UN archivo (sin solापe). El agente principal arma el
**orquestador** (contrato) primero, luego se lanzan los subagentes en paralelo.

### Paso 0 (agente principal, ANTES de lanzar): scaffolding
`ragdoll_character.gd` queda como orquestador que:
- Mantiene refs: `_skel`, `_torso`, `bone(name)`, `_stand_height`, `_target_height`,
  `is_local`, `_stun`, flags y los `@export` de tuning.
- En `_physics_process(delta)` llama, EN ESTE ORDEN:
  ```
  if _stun > 0: combat.tick_stunned(self, delta); return
  balance.tick(self, delta)            # torso vertical + hover + CABEZA rígida
  if is_local: locomotion.tick(self, delta)   # cuerpo como unidad + piernas
  combat.tick(self, delta)             # progreso del punch
  ```
- Crea instancias de los 3 componentes en `_ready`.
- Componentes = `extends RefCounted` con `class_name`, operan sobre el `char` que reciben.

Contrato compartido (lo que los componentes pueden leer/escribir del `char`):
`char._torso`, `char.bone("head"/"arm_l"/...)`, `char._target_height`,
`char._stand_height`, `char.is_local`, `char.move_force`, `char.balance_strength`,
`char.hover_strength`, `char.MAX_RIGHT_SPEED`, `char._stun`, `char.is_ragdoll`.

## Workstreams paralelos (1 archivo c/u)

### WS-A — Balance + cabeza  → `characters/base/components/ragdoll_balance.gd`
- Hover del torso a `_target_height` (mover lo ya existente aquí).
- Enderezado del torso por `angular_velocity` con tope `MAX_RIGHT_SPEED`.
- **Cabeza rígida**: cada frame alinear la orientación del hueso `head` a la del
  `torso` (set `head.angular_velocity` hacia el match, y/o anclar su posición al
  hombro del torso) para que deje de bambolearse. Damp alto en head.

### WS-B — Locomoción + piernas  → `characters/base/components/ragdoll_locomotion.gd`
- Mover **el cuerpo como unidad**: aplicar el impulso de movimiento al torso Y
  arrastrar las piernas (impulso/alineación a leg_l/leg_r) para que no se queden atrás.
- Orientar el "frente" del torso hacia la dirección de avance (yaw).
- Estabilidad de piernas: mantenerlas bajo el torso (objetivo vertical relativo;
  resorte que las recoge). Planting simple de pies cuando está quieto.
- (Sinergia con WS-D: los límites de joint ayudan; aquí va el control activo.)

### WS-C — Combate (punch + knockdown)  → `characters/base/components/ragdoll_combat.gd`
- `punch()`: swing procedural del brazo (impulso a `arm_l`/`arm_r` hacia adelante,
  con pequeño windup y retorno). Estado/timer del golpe en `tick`.
- Mover aquí `knock_down()`, `_recover()`, `tick_stunned()` (caer como trapo + auto
  levantarse) desde el orquestador.
- Enganchar con `attempt_attack`/`deliver_hit`/`receive_hit` (red) que quedan en el
  orquestador llamando a este componente.

### WS-D — Joints & estabilidad física  → `tools/build_gallo_ragdoll.gd` (+ regen `gallo.tscn`)
- **Cabeza**: joint rígido (6DOF con todo bloqueado, o CONE con límite ~0).
- **Piernas**: `CONE_TWIST` con límites (swing ~20-30°, twist chico) → estabilidad,
  no se abren 90°.
- **Brazos**: `CONE_TWIST` límites moderados (que no se desprendan ni flaileen).
- Ajustar masa/damp por hueso para centro de masa bajo (gallo estable).
- Regenerar `gallo.tscn` y verificar headless que carga (6 PhysicalBone3D).
- NO toca Blender (la geometría/rig no cambia); todo es config de joints en Godot.

## Integración y verificación (agente principal, DESPUÉS)
1. Cablear los 3 componentes en el orquestador; resolver orden/conflictos de escritura
   sobre el torso.
2. Probar headless con `tools/test_active.gd` (+ uno nuevo para movimiento y punch):
   parado estable, caminar sin arrastrar piernas, cabeza quieta, punch visible,
   knockdown+recover. Capturas para revisar.
3. Tuning fino de constantes por personaje (gallo = rígido/estable).

## Notas técnicas (aprendidas)
- `PhysicalBone3D` NO tiene `apply_torque_impulse`. Sí: `apply_central_impulse`,
  `apply_impulse(impulse, pos)`, y props `linear_velocity` / `angular_velocity`.
- Huesos en capa 2, máscara 1 (no chocan con la cápsula del cuerpo ni entre sí).
- Correr Godot: `~/Downloads/Godot_v4.6.3-stable_linux.x86_64 --path . --script res://tools/<x>.gd`
  (con ventana para screenshots; `--headless` para lógica sin render).
