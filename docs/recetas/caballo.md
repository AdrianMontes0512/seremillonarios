# 🐴 Receta geométrica — CABALLO (AZUL #2E6FE6)

Altura rig 1.7m · +15% volumen (X/Y) · Z-up · origen en pies · mira -Y.

## Coords de huesos (referencia para pesar)
| Hueso | Cabeza (x,y,z) | Extremo | Rol |
|---|---|---|---|
| torso (root) | (0,0,0.78) | 1.12 | centro masa, tronco |
| head | (0,-0.05,1.18) | 1.55 | cuello largo + cabeza |
| arm_l | (0.26,0,1.05) | (0.34,0,0.55) | brazo izq largo |
| arm_r | (-0.26,0,1.05) | (-0.34,0,0.55) | brazo der largo |
| leg_l | (0.13,0,0.74) | (0.15,0,0) | pierna izq larga |
| leg_r | (-0.13,0,0.74) | (-0.15,0,0) | pierna der larga |

## Primitivas
### Tronco (torso)
1. UV Sphere (0,0,0.92) dim 0.62×0.78×0.74
2. UV Sphere pecho (0,-0.12,1.05) 0.56×0.50×0.46
3. UV Sphere grupa (0,0.22,0.86) 0.54×0.46×0.50

### Cuello+cabeza (head)
4. Cone troncado cuello (0,-0.08,1.25) Ø0.26→0.20 alto0.34, tilt ~15° -Y
5. UV Sphere cráneo (0,-0.14,1.46) 0.24×0.26×0.26
6. Cube hocico (0,-0.30,1.42) 0.18×0.26×0.20
7. UV Sphere×2 orejas (±0.08,-0.06,1.58) 0.06×0.05×0.10

### Brazos (largos 0.52m)
8. Cylinder brazo_l (0.30,0,0.80) Ø0.16 h0.52, ~12° fuera → arm_l
9. UV Sphere casco_l (0.34,0,0.52) 0.18 → arm_l
10/11 espejo → arm_r

### Piernas (largas 0.74m)
12. Cylinder pierna_l (0.13,0,0.38) Ø0.20 h0.74 → leg_l
13. Cube casco_l (0.13,-0.04,0.04) 0.22×0.30×0.08 → leg_l
14/15 espejo → leg_r

### Cosméticos (sin física)
16. mane (crin): 4-5 conos bajos sobre cuello → head
17. tail: cono alargado (0,0.32,0.78) Ø0.10 h0.40, ~40° abajo+Y → torso

## Materiales
- base #2E6FE6 (rough 0.9, sin metal)
- ojo_blanco #F2F2F2, pupila #101018, hocico_oscuro #1E4FB0, casco_gris #3A4256 (opc)

## Weights
torso=cuerpo+base cuello+arranques; head=cuello(z>1.12)+cráneo+hocico+orejas+crin; brazos+cascos→arm; piernas+pies→leg. Cosméticos 100% rígido al hueso anfitrión. Normalize All + Limit Total 4.
