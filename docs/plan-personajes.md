# Plan de modelado — Los 4 personajes (estilo Gang Beasts)

Referencia visual: animales rechonchos, bípedos, caricaturescos, de un solo color
sólido cada uno, proporciones tipo Gang Beasts / Fall Guys. Cuerpo grande y blando,
extremidades cortas y gruesas. Sin texturas complejas — color plano + sombreado.

Todos comparten el **mismo esqueleto de 6 huesos** definido en
[`blender-rig-spec.md`](blender-rig-spec.md): `torso` (raíz), `head`, `arm_l`,
`arm_r`, `leg_l`, `leg_r`. Lo que cambia entre animales es la **silueta de la malla**
y los **valores de física** (ya están en el código de cada `*.gd`).

---

## Reglas comunes (los 4)
- Altura ≈ **1.7 m**, T-pose, mirando al frente (-Y en Blender).
- Estilo **low-poly liso** (poca geometría, formas redondeadas). Subdivisión suave OK.
- **Un color sólido** por personaje (albedo plano). Detalles (ojos, pico) como
  geometría o islas de color, no texturas.
- Origen en los pies, transformaciones aplicadas, export `.glb` (+Y up, apply mods).
- Cada malla pesada al armature de 6 huesos. Los detalles cosméticos (cola, pico,
  orejas) pueden colgar de huesos extra **sin física**.

---

## 1. 🐔 Gallo — ROJO `#E61F1F`
**Personalidad física:** difícil de derribar, combate directo.
- **Silueta:** cuerpo ovalado robusto, pecho prominente, patas cortas y fuertes.
  Cresta roja sobre la cabeza, pico amarillo pequeño, cola de plumas hacia atrás.
- **Detalles cosméticos (huesos extra opcionales):** `comb` (cresta), `tail_feathers`.
- **Centro de masa bajo** → el torso debe quedar más pesado/bajo en la silueta.
- Física (ya en `gallo.gd`): mass 75, ragdoll_threshold 20, launch 0.7. El más estable.

## 2. 🐴 Caballo — AZUL `#2E6FE6`
**Personalidad física:** el más grande, lento, devastador al caer.
- **Silueta:** el más alto y voluminoso. Cuello largo, cabeza alargada (hocico),
  extremidades más largas (mayor alcance). Crin corta, cola.
- **Detalles cosméticos:** `mane` (crin), `tail`.
- Escálalo ~15% más grande que el resto manteniendo la altura base de referencia
  del rig (la diferencia se siente, no rompe el esqueleto).
- Física (ya en `caballo.gd`): el más pesado, casi no vuela, más daño al caer.

## 3. 🦝 Mapache — VERDE `#37C837`
**Personalidad física:** pequeño, ligero, sale volando lejos.
- **Silueta:** el más **pequeño y delgado**. Cabeza con antifaz (máscara de mapache),
  orejas puntiagudas, cola anillada gruesa. Cuerpo compacto.
- **Detalles cosméticos:** `tail` (cola anillada, llamativa), `ears`.
- Hazlo notablemente más chico → cuesta agarrarlo y vuela el doble.
- Física (ya en `mapache.gd`): el más liviano y rápido, ragdoll_threshold bajo.

## 4. 🐱 Gato — MORADO `#9B3BE6`
**Personalidad física:** flexible, impredecible, articulaciones sueltas.
- **Silueta:** esbelto y curvo, postura relajada. Orejas triangulares, hocico chato,
  cola larga y delgada muy expresiva.
- **Detalles cosméticos:** `tail` (larga), `ears`.
- En Godot configuraré sus joints con **más libertad angular** (CONE_TWIST amplio)
  para que su ragdoll se vea más "blando" que los demás.
- Física (ya en `gato.gd`): equilibrado, launch_multiplier alto, joints flexibles.

---

## Orden de trabajo recomendado
1. **Gallo primero** (vertical completa): modelar → riggear 6 huesos → pesar → export.
2. Yo lo importo en Godot, genero los `PhysicalBone3D`, ajusto joints y valido el
   ragdoll en red. Cerramos el pipeline con 1 personaje.
3. Repetir para Caballo, Mapache y Gato (reusando el mismo esqueleto base).

> Tip: modela primero **un "personaje base" genérico** con el rig de 6 huesos y
> guárdalo como `.blend` plantilla. Luego cada animal es ese base + cambios de
> silueta y color. Así los 6 huesos quedan idénticos en los 4 y todo encaja en Godot.

---

## Checklist por personaje antes de exportar
- [ ] Altura ≈ 1.7 m, origen en los pies, transforms aplicados
- [ ] Armature con exactamente: `torso, head, arm_l, arm_r, leg_l, leg_r`
- [ ] `torso` es la raíz del armature
- [ ] Malla pesada (weight paint) sin vértices sueltos
- [ ] Color sólido correcto (rojo/azul/verde/morado)
- [ ] Export `.glb` con +Y Up + Apply Modifiers, sin animaciones
- [ ] Guardado en `characters/<animal>/mesh/<animal>.glb`
