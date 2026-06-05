# Estado de la sesión — punto de retomar

_Última actualización: 2026-06-04_

## Dónde quedamos
Estamos a punto de empezar a **modelar los 4 personajes en Blender** asistidos por
IA vía **Blender MCP**. Todo el setup quedó hecho; solo falta reconectar Claude.

## ✅ Lo que ya funciona
- **Multiplayer Steam (GodotSteam GDExtension 4.19.1)** corriendo con editor Godot
  4.6.3 estándar. AppID 480 (Spacewar) para dev.
- Flujo de 2 instancias host/cliente verificado online entre 2 PCs (Arch + Windows).
- Bugs de red resueltos: el que entra ve al host, sin spawn en el piso, salto del
  cliente con gravedad, sin "peer fantasma" al crear lobby.
- Cámara agregada a `TestArena` (antes no se veía nada).
- Todo commiteado y pusheado a `git@github.com:AdrianMontes0512/seremillonarios.git`
  (rama `main`).

## ✅ Setup de Blender + MCP (hecho hoy)
- Blender **5.1.2** instalado (`pacman`), `uv`/`uvx` instalados.
- Addon **Blender MCP** instalado y **activado** (guardado en prefs de Blender).
- Servidor MCP `blender` registrado en `.mcp.json` (`uvx blender-mcp`), pusheado.
- En Blender: "Connect to Claude" activo → **"Running on port 9876"** confirmado.

## ✅ Gallo modelado y exportado (2026-06-04)
- Armature base de 6 huesos creado (`torso` raíz + head/arm_l/arm_r/leg_l/leg_r),
  Z-up, origen en pies, altura ≈1.7 m. Plantilla en `characters/_blend/gallo.blend`.
- Gallo 🐔 modelado low-poly (cuerpo ovalado rojo `#E61F1F`, cresta, pico/pies
  amarillos, ojos, barbas, cola abanicada). ~2104 verts.
- **Skinning rígido por hueso** (vertex groups manuales, 1 hueso por vértice → ideal
  para ragdoll). Prueba de pose OK: cada parte sigue a su hueso.
- Exportado: `characters/gallo/mesh/gallo.glb` (+Y up, apply mods, sin animaciones).
- Recetas geométricas de los otros 3 listas en `docs/recetas/{caballo,mapache,gato}.md`.

## ✅ Gallo integrado en Godot con ragdoll (2026-06-04)
- `characters/gallo/gallo.tscn` regenerado con la estructura que exige la red:
  `Gallo (CharacterBody3D)` → `CollisionShape3D` (cápsula caminar) + `Skeleton3D`
  (hijo directo) → `MeshInstance gallo` + 6 `PhysicalBone3D` (torso=joint NONE raíz,
  resto=PIN). Generado por `tools/build_gallo_ragdoll.gd` (headless).
- Pico corregido (apuntaba al revés). Rig verificado: torso=[0] raíz, 6 huesos,
  0 verts sin peso.
- **Ragdoll validado localmente** con `tools/test_ragdoll.gd`: se renderiza como
  gallo, cae y la malla sigue a los huesos. Screenshots en `tools/ragdoll_*.png`.

## ✅ ACTIVE RAGDOLL estilo Gang Beasts (2026-06-05)
`ragdoll_character.gd` reescrito: el personaje está SIEMPRE en simulación física.
- Ya NO usa `move_and_slide` (eso causaba el "salir volando" peleando con sus huesos).
- El torso es el cuerpo de control: `gravity_scale=0` + resorte de altura (hover) lo
  mantiene parado; control de `angular_velocity` (con tope `MAX_RIGHT_SPEED`) lo
  endereza; las patas cuelgan con gravedad.
- Movimiento = `apply_central_impulse` horizontal al torso. Salto = impulso vertical.
- Golpe (`receive_hit`→`knock_down`): el torso recupera gravedad + recibe impulso y
  queda `_stun` segundos sin equilibrio (se cae). Al pasar el stun, `_recover()` vuelve
  a flotar y se levanta solo a `_stand_height`.
- OJO PhysicalBone3D: NO tiene `apply_torque_impulse`; sí `apply_central_impulse`,
  `linear_velocity`, `angular_velocity` (por eso el enderezado controla angular_velocity).
- Validado headless con `tools/test_active.gd`: parado estable (up=1.0, no vuela),
  knockdown y auto-recuperación. Capturas `tools/active_*.png`.
- Para inspeccionar: dar play a `gallo.tscn` (el equilibrio corre aunque is_local=false).

## ✅ Refinamiento por componentes (2026-06-05)
`ragdoll_character.gd` ahora es un ORQUESTADOR que delega en 3 componentes
(`characters/base/components/`), cada uno desarrollado por un subagente en paralelo:
- `ragdoll_balance.gd` — hover + enderezado del torso + **cabeza rígida** (alinea head
  al torso por angular_velocity + ancla de posición). head_gap se mantiene constante.
- `ragdoll_locomotion.gd` — **movimiento como unidad**: empuja torso y arrastra piernas;
  resorte HORIZONTAL que mantiene las piernas bajo el torso (leg_gap constante, ya no se
  arrastran ni se abren); yaw hacia la dirección; tope de velocidad. `apply_remote` igual.
- `ragdoll_combat.gd` — **punch procedural** (windup→swing, alterna brazos) + knockdown
  con spin + recuperación.
- Joints CONE (en `tools/build_gallo_ragdoll.gd` → `gallo.tscn`): head 6°, piernas 25°,
  brazos 50° de swing.
- Tuning gallo: move_force 6.5, balance_strength 20, hover_strength 38, MAX_RIGHT_SPEED 9.
- Verificado con `tools/test_active.gd` (parado/knockdown/recuperación) y
  `tools/test_move.gd` (movimiento + punch). Capturas en `tools/*.png`.

### Pendiente de tuning fino (feel)
- Al caminar sostenido se inclina un poco hacia adelante (up≈0.89, no se cae) — se puede
  pulir más (anti-tip, fricción de pies, o empujar piernas primero).
- El get-up tras knockdown es algo lento (~3 s). Subir hover/asistencia de recuperación.

## ✅ Migración a Active Ragdoll 6DOF (2026-06-05)
Arquitectura ALTERNATIVA (la pediste): 6 `RigidBody3D` independientes unidos por
`Generic6DOFJoint3D` (músculos angular spring) + PID de equilibrio en el torso.
- Malla del gallo separada en 6 piezas por vertex group → `characters/gallo/mesh/gallo_parts.glb`
  (blend en `characters/_blend/gallo_parts.blend`).
- `characters/base/ActiveRagdollController.gd` (locomoción, PID erguido, brazos arriba,
  dive, punch, knockout) + `GrabController.gd` (PinJoint3D dinámico). Guía en
  `docs/active-ragdoll-6dof/GUIA.md`.
- `tools/build_gallo_6dof.gd` genera `characters/gallo/gallo_6dof.tscn` (6 RigidBody con
  malla+caja de colisión desde AABB, 5 joints, scripts y params asignados).
- InputMap ampliado: punch_left/right (clicks), raise_arms (Q), dive (Shift), grab_left/right (Z/X).
- Escena jugable: `scenes/arena_6dof.tscn` (F6 para probar con WASD + mouse).
- Validado headless: se para erguido (up=1.0), **camina derecho** (mejor que la versión
  PhysicalBone), punch lanza el brazo, knockout se desploma como desmayado. Capturas
  `tools/6dof_*.png`, `tools/act_*.png`, `tools/arena6_check.png`.

### Pendiente de tuning/feature 6DOF
- Recuperación tras KO: confirmar que se levanta del todo (ko_duration 2.5s).
- Colisiones por CAJA (AABB); pasar a cápsulas para mejor feel.
- Grab/dive aún sin validar en juego (probar con mouse/Shift).
- Decidir cuál arquitectura es la definitiva: 6DOF (esta) vs PhysicalBone (componentes).

## ⏭️ Próximo paso
1. Que el usuario pruebe el feel en el editor (play a `gallo.tscn`) y ajustar constantes.
2. **Red para active-ragdoll:** sincronizar huesos SIEMPRE (no solo en `is_ragdoll`) y que
   el remoto NO corra equilibrio local (siga los huesos del host). Ajustar `network_manager.gd`.
3. Replicar a Caballo/Mapache/Gato (mismo pipeline + tuning por personaje).
3. Repetir el pipeline Blender→Godot para **Caballo, Mapache, Gato** usando
   `characters/_blend/gallo.blend` como base + recetas en `docs/recetas/`.

## 🔧 Pipeline reusable (para los otros 3)
- Modelar en Blender sobre el rig de 6 huesos (vertex groups rígidos por hueso).
- Export `.glb` a `characters/<animal>/mesh/`.
- Adaptar `tools/build_gallo_ragdoll.gd` (cambiar rutas + tabla TAILS/MASSES) y correr
  headless para generar el `.tscn`.

## ⚠️ Pendiente conocido (no bloquea)
- El **ragdoll no se ve todavía** porque los modelos actuales son cápsulas con
  `Skeleton3D` vacío (sin `PhysicalBone3D`). Se resuelve al traer los modelos
  riggeados de Blender. Lo de hoy (movimiento/red) sí funciona.

## Notas de toolchain (para no repetir)
- Correr el juego: `~/Downloads/Godot_v4.6.3-stable_linux.x86_64 --path <proyecto>`
- `steam_appid.txt` (contenido: `480`) está en `.gitignore` → cada quien lo crea.
- Con la GDExtension hay que exportar con templates NORMALES de Godot, no los de
  GodotSteam.
