# Guía — Active Ragdoll de 6 huesos (RigidBody3D + Generic6DOFJoint3D)

Diseño estilo Gang Beasts donde el personaje es 100% físico: 6 `RigidBody3D`
unidos por 5 `Generic6DOFJoint3D` que actúan como "músculos" (angular spring),
más un PID que mantiene el torso erguido. Scripts en esta misma carpeta:
`ActiveRagdollController.gd` y `GrabController.gd`.

> API verificada en Godot 4.6.3 (este proyecto).

---

## 1. Jerarquía de nodos

```
Player (Node3D)                         [ActiveRagdollController.gd]
├── Bones (Node3D)                      # contenedor visual, opcional
│   ├── Torso (RigidBody3D)             # cuerpo lógico raíz (igual es dinámico)
│   │   ├── ColTorso (CollisionShape3D — Capsule)
│   │   └── MeshTorso (MeshInstance3D)
│   ├── Head  (RigidBody3D)   → Col + Mesh
│   ├── ArmL  (RigidBody3D)   → Col + Mesh   [GrabController.gd, action="grab_left"]
│   ├── ArmR  (RigidBody3D)   → Col + Mesh   [GrabController.gd, action="grab_right"]
│   ├── LegL  (RigidBody3D)   → Col + Mesh
│   └── LegR  (RigidBody3D)   → Col + Mesh
└── Joints (Node3D)
    ├── J_Head  (Generic6DOFJoint3D)   node_a=../Bones/Torso  node_b=../Bones/Head
    ├── J_ArmL  (Generic6DOFJoint3D)   node_a=Torso  node_b=ArmL
    ├── J_ArmR  (Generic6DOFJoint3D)   node_a=Torso  node_b=ArmR
    ├── J_LegL  (Generic6DOFJoint3D)   node_a=Torso  node_b=LegL
    └── J_LegR  (Generic6DOFJoint3D)   node_a=Torso  node_b=LegR
```

Reglas de oro de colocación:
- **Cada Generic6DOFJoint3D se coloca en el PUNTO de la articulación** (cuello,
  hombros, caderas), no en el centro del hueso. El joint usa SU propia posición
  y orientación como punto de anclaje y como marco de referencia de los límites
  angulares. Orienta su eje según cómo quieras que abra (ver §3).
- `node_a` = Torso, `node_b` = el miembro. El orden importa para el signo de los
  ángulos del resorte (equilibrium_point).
- En el Inspector de cada joint asigna `Nodes > Node A` y `Node B`.

En el `Player` arrastra al Inspector las 6 referencias de RigidBody y los 5 joints
(los `@export` del controlador).

---

## 2. Parámetros recomendados de los RigidBody3D

| Hueso | Mass | Center of Mass (custom) | Collision Shape | Notas |
|------|------|-------------------------|-----------------|-------|
| Torso | 6.0 | (0, −0.15, 0) | Capsule r0.3 h0.7 | CoM bajo = estable |
| Head  | 1.5 | (0,0,0) | Sphere r0.18 | |
| ArmL/ArmR | 1.0 | (0,0,0) | Capsule r0.09 h0.4 | livianos |
| LegL/LegR | 2.0 | (0,0,0) | Capsule r0.1 h0.7 | peso abajo |

Ajustes comunes (los fuerza el script en `_ready`, pero conviene en el Inspector):
- **Can Sleep = OFF** en todos: si se duermen, los músculos dejan de actuar.
- **Contact Monitor = ON** y **Max Contacts Reported ≥ 4** en torso, cabeza y manos
  (para `body_entered` del knockout y del agarre).
- **Linear Damp ≈ 0.5**, **Angular Damp ≈ 2–4**: estabilidad / menos vibración.
- **Gravity Scale = 1** (el torso también cae; el PID lo mantiene de pie).
- **Collision Layer/Mask**: pon los 6 huesos en una capa "jugador" y el mundo en otra.
  El script llama `add_collision_exception_with` entre todos los huesos del mismo
  personaje para que NO se auto-colisionen (si no, los joints vibran).

Centro de masa por código:
```gdscript
torso.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
torso.center_of_mass = Vector3(0, -0.15, 0)
```

---

## 3. Parámetros de los Generic6DOFJoint3D (los "músculos")

Cada joint se configura por eje (`x`, `y`, `z`) con `set_param_x/y/z` y
`set_flag_x/y/z`. **Los ángulos van en RADIANES por código** (el Inspector los
muestra en grados). Constantes verificadas en 4.6.3:

| Constante | Valor | Para qué |
|---|---|---|
| `FLAG_ENABLE_ANGULAR_LIMIT` (1) | true | activar tope mecánico del eje |
| `PARAM_ANGULAR_LOWER_LIMIT` (10) / `UPPER_LIMIT` (11) | ±swing (rad) | rango de giro |
| `FLAG_ENABLE_ANGULAR_SPRING` (2) | true | activar el "músculo" |
| `PARAM_ANGULAR_SPRING_STIFFNESS` (19) | 120 | rigidez del músculo |
| `PARAM_ANGULAR_SPRING_DAMPING` (20) | 8 | amortiguación |
| `PARAM_ANGULAR_SPRING_EQUILIBRIUM_POINT` (21) | 0 (rad) | pose objetivo (0 = reposo) |
| `FLAG_ENABLE_MOTOR` (4) + `PARAM_ANGULAR_MOTOR_TARGET_VELOCITY` (17) / `FORCE_LIMIT` (18) | — | alternativa al spring (motor de velocidad) |

Límites (swing) recomendados por hueso, feel "estable pero con vida":

| Joint | swing | stiffness | damping | Idea |
|------|-------|-----------|---------|------|
| J_Head | 8° | 200 | 10 | casi rígida con el torso |
| J_ArmL/R | 90° | 120 | 8 | mueven libre pero vuelven a reposo |
| J_LegL/R | 35° | 160 | 10 | estables, no se abren |

Patrón de configuración (lo hace `_setup_muscle` en el script):
```gdscript
var lim := deg_to_rad(swing_deg)
for axis in ["x","y","z"]:
    j.call("set_flag_"+axis,  Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
    j.call("set_param_"+axis, Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -lim)
    j.call("set_param_"+axis, Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT,  lim)
    j.call("set_flag_"+axis,  Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_SPRING, true)
    j.call("set_param_"+axis, Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, 120.0)
    j.call("set_param_"+axis, Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_DAMPING, 8.0)
    j.call("set_param_"+axis, Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_EQUILIBRIUM_POINT, 0.0)
```

> Spring vs Motor: el **angular spring** es un resorte hacia un ángulo objetivo
> (ideal para "mantener pose" y para levantar brazos cambiando el equilibrium).
> El **motor** (`FLAG_ENABLE_MOTOR`) gira a una velocidad objetivo con un tope de
> fuerza (útil para un giro continuo). Aquí usamos spring por su comportamiento
> tipo músculo; el punch usa impulso directo al RigidBody.

---

## 4. Mecánicas, paso a paso (ActiveRagdollController.gd)

1. **`_ready`** — excepciones de auto-colisión entre huesos, `can_sleep=false`,
   `contact_monitor=true`, CoM del torso, configura los 5 músculos y conecta
   `body_entered` de torso/cabeza para el knockout.

2. **Locomoción (`_apply_locomotion`)** — lee WASD, y mientras la velocidad
   horizontal no llegue a `max_speed` aplica `torso.apply_central_force(dir*move_force)`.
   Además `_face_direction` aplica un torque en Y para que el frente (−Z) del torso
   mire hacia donde avanza. (Mover el torso arrastra los miembros por los joints.)

3. **Equilibrio erguido (`_apply_upright`)** — PID sobre el torso:
   `torque = Kp*ángulo_inclinación*eje − Kd*velocidad_angular`, aplicado con
   `torso.apply_torque(...)`. Se anula la componente Y (eso lo maneja el yaw).
   `_balance_scale` escala todo: 1 normal, 0 cuando hace dive o está KO.

4. **Levantar brazos (`_apply_arms`)** — mientras se mantiene `raise_arms`,
   interpola `_arms_up` 0→1 y mueve el `EQUILIBRIUM_POINT` del eje X de los joints
   de los brazos a `−arm_raise_angle` → los brazos suben sobre la cabeza.

5. **Dive (`_dive`)** — `torso.apply_central_impulse(fwd*dive_impulse)` y pone
   `_dive_timer` (durante el cual `_balance_scale=0` → el personaje colapsa hacia
   adelante de forma cómica). También afloja temporalmente el resorte de las piernas.

6. **Punch (`_punch`)** — `arm.apply_torque_impulse(swing_axis*punch_torque)` para
   lanzar el brazo hacia adelante + `arm.apply_central_impulse(fwd*...)`. Con
   cooldown por brazo. (Click izq/der → brazo izq/der.)

7. **Knockout (`_on_bone_impact` → `_knockout`)** — en `body_entered` calcula la
   velocidad relativa de impacto (proxy de fuerza). Si supera `ko_velocity_threshold`:
   pone la rigidez/damping de TODOS los músculos a 0 y `_balance_scale=0` durante
   `ko_duration` → ragdoll pasivo (cae desmayado). Al terminar, `_recover_from_ko`
   restaura los músculos y el personaje se vuelve a parar.

---

## 5. Agarre (GrabController.gd)

Uno por brazo (mano). Usa `contact_monitor` del RigidBody de la mano para llevar
una lista de cuerpos en contacto. Mientras se mantiene el botón (`grab_left`/
`grab_right`) y haya contacto, crea un `PinJoint3D` por código atando la mano al
objeto; al soltar, lo destruye.

Detalle clave de Godot 4: `node_a`/`node_b` del joint son **NodePaths relativos
al propio joint**. Por eso:
```gdscript
_grab_joint.node_a = _grab_joint.get_path_to(hand_body)
_grab_joint.node_b = _grab_joint.get_path_to(target)
```
El joint se agrega a la escena y se posiciona en `hand_body.global_position`.

---

## 6. InputMap a crear (Proyecto > Ajustes del Proyecto > Mapa de Entrada)

`move_left, move_right, move_forward, move_back` (WASD), `raise_arms` (p.ej. Espacio),
`dive` (Shift), `punch_left` (Click Izq), `punch_right` (Click Der),
`grab_left` (Click Izq) y `grab_right` (Click Der).
> Nota: `punch_*` y `grab_*` comparten botón: el punch dispara en el "just pressed"
> y el grab actúa mientras se mantiene. Si quieres separarlos, usa botones distintos.

---

## 7. Relación con el sistema actual del proyecto

Hoy el proyecto usa **otra arquitectura** (un solo `CharacterBody3D` + `Skeleton3D`
con `PhysicalBone3D` y malla skinneada — ver `characters/base/`). Este diseño 6DOF
es una **alternativa** con huesos independientes:
- Pros: control de "músculos" muy explícito (springs/motors), agarre y dive directos.
- Contras: la malla ya no es una sola piel; cada `RigidBody3D` lleva su propio
  `MeshInstance3D` (trozo del personaje), o se re-mapea la piel a 6 cuerpos.
- Para adoptarlo en el gallo habría que partir la malla en 6 piezas (o instanciar
  primitivas por hueso) y armar la jerarquía de §1.

Estos scripts están como **referencia lista para usar**; no están cableados en el
proyecto para no romper el gallo que ya funciona. Si decidimos migrar, montamos una
escena `player_6dof.tscn` con la jerarquía y asignamos los scripts.
