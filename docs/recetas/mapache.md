# 🦝 Receta geométrica — MAPACHE (VERDE #37C837)

El más pequeño: ocupa ~1.25m dentro de caja 1.7m. Delgado, cabeza grande, cola gruesa anillada. Origen en pies, mira -Y.

## Primitivas
| # | Primitiva | Pos (x,y,z) | Dim (X,Y,Z) | Rot | Hueso |
|---|---|---|---|---|---|
| 1 | UV Sphere torso | 0,0,0.62 | 0.40×0.34×0.50 | — | torso |
| 2 | Cylinder cuello | 0,0,0.90 | Ø0.16×0.10 | — | torso/blend head |
| 3 | UV Sphere cabeza | 0,-0.02,1.02 | 0.30×0.30×0.28 | — | head |
| 4 | Cone hocico | 0,-0.16,0.99 | Ø0.13×0.15 | X+90° | head |
| 5 | UV Sphere nariz | 0,-0.23,1.00 | 0.04 | — | head |
| 6 | Cone oreja_l | 0.11,0.02,1.20 | Ø0.10×0.14 | tiltX-10° | head cosm |
| 7 | Cone oreja_r | -0.11,0.02,1.20 | Ø0.10×0.14 | — | head cosm |
| 8 | Cylinder brazo_l | 0.26,0,0.78 | Ø0.10×0.40 | Y+8° | arm_l |
| 9 | Cylinder brazo_r | -0.26,0,0.78 | Ø0.10×0.40 | Y-8° | arm_r |
| 10/11 | UV Sphere manos | ±0.30,0,0.56 | 0.10 | — | arm_l/r |
| 12/13 | Cylinder piernas | ±0.13,0,0.24 | Ø0.12×0.45 | — | leg_l/r |
| 14/15 | UV Sphere pies | ±0.13,-0.05,0.04 | 0.13×0.18×0.08 | — | leg_l/r |
| 16 | Cola anillada (5 segs cyl Ø0.16) | 0,0.22,0.70 | h~0.55 | X-55° sube atrás | torso cosm |
| 17 | Cone punta cola | 0,0.30,1.05 | Ø0.16→0.08×0.18 | — | torso cosm |

## Materiales (albedo plano)
- base #37C837 (rough 0.9)
- antifaz/anillos/punta cola/nariz #1F1F1F
- ojos #FFFFFF + pupila #101010
- acento claro #5FE05F (hocico/pecho opc), interior orejas #2A8F2A
- Antifaz: banda horizontal sobre ojos cruzando de oreja a oreja (marca registrada).

## Weights
torso=tronco+cuello+cola base+manos; head=cabeza+hocico+nariz+orejas+antifaz (blend cuello 50/50); brazos+manos→arm; piernas+pies→leg (blend cadera 0.2). Cola/orejas 100% rígido. Clean + sin vértices peso 0.
