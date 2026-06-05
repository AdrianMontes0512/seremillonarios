# 🐱 Receta geométrica — GATO (MORADO #9B3BE6)

Esbelto, curvo (columna en S), postura relajada. Altura ~1.7m. Origen pies, mira -Y.

## Primitivas
| # | Primitiva | Pos (x,y,z) | Dim (X,Y,Z) | Rot | Hueso |
|---|---|---|---|---|---|
| 1 | UV Sphere torso | 0,0.02,1.07 | 0.30×0.24×0.50 | tiltX-8° | torso |
| 2 | UV Sphere cadera | 0,0,0.86 | 0.26×0.22×0.18 | — | torso |
| 3 | UV Sphere cabeza | 0,-0.04,1.55 | 0.24×0.23×0.24 | — | head |
| 4 | Cylinder cuello | 0,-0.02,1.36 | r0.055 h0.16 | tiltX-15° | head50/torso50 |
| 5 | Cube hocico chato | 0,-0.16,1.50 | 0.12×0.07×0.07 | — | head |
| 6/7 | Cone orejas | ±0.10,-0.02,1.74 | r0.07 h0.16 | — | head cosm |
| 8/10 | Cylinder brazos | ±0.26,0,1.05 | r0.05 h0.42 | cuelga | arm_l/r |
| 9/11 | UV Sphere manos | ±0.26,0,0.82 | 0.07 | — | arm_l/r |
| 12/14 | Cylinder piernas | ±0.10,0,0.46 | r0.06 h0.76 | — | leg_l/r |
| 13/15 | Cube pies | ±0.10,-0.06,0.04 | 0.10×0.20×0.08 | — | leg_l/r |
| 16-19 | Cola larga (3 cyl + cono punta) curva | 0,0.16→0.50,0.95→1.40 | r0.035→0.022 | tilt +55→-30° | torso cosm |

## Materiales
- base #9B3BE6 (rough alto)
- interior orejas #E6A8F0, hocico/nariz #3A1452
- ojos #F2ECF7 + pupila vertical #1A0A24 (en ±0.07,-0.21,1.57)
- vientre #B86BF0 (opc)

## Weights
torso=tronco+cadera+cola+50% cuello (ancla física); head=cabeza+hocico+orejas+ojos+50% cuello; brazos+manos→arm (hombro 30% torso); piernas+pies→leg (cadera 40% torso). Cola 100% torso (vertex group tail_jiggle para spring bones en Godot). Orejas 100% head. Joints MÁS sueltos en Godot (CONE_TWIST amplio).
