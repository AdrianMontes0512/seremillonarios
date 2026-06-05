# Especificación de modelos Blender → Godot (ragdoll)

Esta spec garantiza que el modelo funcione con `ragdoll_character.gd` y la
sincronización de huesos en `network_manager.gd` **sin tocar código**.

## 1. Escala y orientación
- **Unidades:** metros. Altura del personaje ≈ **1.7 m** (como la cápsula actual).
- **Up axis:** Z-up en Blender (normal). Al exportar glTF se convierte a Y-up de Godot.
- **Pose:** T-pose o A-pose, mirando hacia **-Y de Blender** (= -Z de Godot, "hacia el frente").
- **Origen del objeto** en los pies, centrado en X/Z (0,0).
- Aplicar transformaciones antes de exportar: `Object > Apply > All Transforms`.

## 2. Armature — huesos OBLIGATORIOS (nombres exactos)
El esqueleto debe tener **exactamente estos 6 huesos** con estos nombres
(en inglés, sin tildes, respetando mayúsculas):

```
Armature
└── torso        ← hueso raíz / centro de masa (DEBE ser el primero/root)
    ├── head
    ├── arm_l
    ├── arm_r
    ├── leg_l
    └── leg_r
```

- `torso` es la raíz. El código aplica el impulso del golpe al **primer**
  PhysicalBone3D, así que torso debe quedar primero en la jerarquía.
- Los nombres se usan tal cual para sincronizar la posición/rotación por red.
  Si cambias un nombre, hay que cambiarlo también en el código.
- Más huesos están bien (dedos, cola, pico), pero **estos 6 deben existir**
  porque son los que llevan física. Los extra serán cosméticos (sin física).

## 3. Skinning
- Malla única, pesada (weight paint) al armature. Cada vértice influido
  principalmente por 1–2 huesos. Evitar pesos a más de 4 huesos por vértice.
- Triángulos o quads; Godot triangula al importar.

## 4. Exportar (glTF 2.0)
`File > Export > glTF 2.0 (.glb)` con:
- Format: **glTF Binary (.glb)**
- Include: **Selected Objects** (malla + armature)
- Transform: **+Y Up** ✅
- Data > Mesh: **Apply Modifiers** ✅
- Data > Armature: **Export Deformation Bones Only** (opcional, recomendado)
- **No** exportar animaciones (no las usamos; el ragdoll es pura física)

Nombre del archivo: `gallo.glb`, `caballo.glb`, `mapache.glb`, `gato.glb`.
Colócalos en `characters/<animal>/mesh/`.

## 5. Qué hago yo en Godot (cuando me pases el .glb)
1. Importo el `.glb` → genera un `Skeleton3D` con tus huesos.
2. Uso **"Create Physical Skeleton"** de Godot para generar los `PhysicalBone3D`
   automáticamente a partir de tus 6 huesos (cápsulas de colisión por hueso).
3. Ajusto joints (límites angulares) por personaje según el GDD
   (el gato más suelto, el gallo más rígido, etc.).
4. Reemplazo la cápsula placeholder por tu malla, conservando el script y los
   `@export` de física de cada animal.

## 6. Para empezar rápido
Con **un solo modelo** (ej. `gallo.glb`) ya puedo montar todo el pipeline y
validarlo. Una vez que el primero funcione, los otros 3 son repetir el paso.
