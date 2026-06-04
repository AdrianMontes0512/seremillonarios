# Game Design Document
## Juego sin título — Gang Beasts × Ultimate Chicken Horse

> **Estado:** Concepto inicial  
> **Género:** Party / Physics / Platformer  
> **Plataforma objetivo:** Steam  
> **Jugadores:** 4 máximo  
> **Duración de sesión:** 15–25 minutos

---

## 1. Concepto central

Una fusión entre la física ragdoll y el combate torpe de **Gang Beasts** y el sistema de construcción colaborativa/sabotaje de **Ultimate Chicken Horse**.

Cada partida alterna entre dos fases: los jugadores **construyen el nivel** colocando plataformas y trampas, y luego lo **corren** golpeándose entre sí con física impredecible. Las piezas de rondas anteriores permanecen — para la ronda final el nivel es un laberinto de caos acumulado que nadie controla completamente.

### La frase central
> *"Construí algo brillante y el caos lo destruyó todo."*

### Por qué funciona para stream
- El chat ve la trampa perfecta fallar de formas inesperadas
- Cada ronda genera una historia diferente — nunca hay dos iguales
- Los clips se crean solos: ragdolls, trampas propias que matan al constructor, caos acumulado

---

## 2. Identidad

### Tono visual confirmado
- **Caricaturesco y colorido — Cartoon Network vibes**
- Personajes son **animales antropomórficos** con cuerpos exagerados y física ragdoll
- Cada personaje tiene un color sólido dominante que lo identifica en pantalla de forma inmediata (rojo, azul, verde, morado — sin confusión en el caos)
- Sin violencia percibida — los personajes rebotan, vuelan y se recuperan, estilo cartoon clásico
- Apto para audiencias amplias sin perder el caos

### Referente visual directo
El concept art confirma la dirección: gallo rojo, caballo azul, mapache verde, gato morado. Siluetas claras, colores saturados, proporciones exageradas. Ese es el target visual.

### Niveles — sin setting único
Los niveles son **escenarios variados sin un universo narrativo central**, igual que UCH. Cada nivel tiene su propio tema visual (construcción, selva, ciudad, espacio, cocina, etc.) sin necesidad de que compartan lore. Lo que los une es el estilo cartoon consistente, no el setting.

Ventajas concretas:
- Libertad creativa total por nivel — cada uno puede tener sus propias piezas temáticas
- Más fácil de expandir con updates sin romper coherencia de mundo
- El jugador no se cansa de un solo ambiente

---

## 3. Loop de una partida

Una partida dura **15–25 minutos**, compuesta de **6 rondas**. No hay menús entre fases — la transición es inmediata para mantener el ritmo en stream.

```
Ronda 1 → fase construcción (30s) → fase carrera → resultado
Ronda 2 → fase construcción (30s) → fase carrera → resultado
Ronda 3 → EVENTO DE NIVEL → fase construcción (30s) → fase carrera → resultado
Ronda 4 → fase construcción (30s) → fase carrera → resultado
Ronda 5 → EVENTO DE NIVEL → fase construcción (30s) → fase carrera → resultado
Ronda 6 → fase construcción (30s) → fase carrera → resultado final → pantalla ganador
```

El nivel es el **mismo escenario durante toda la partida**. Las piezas colocadas en ronda 1 siguen ahí en ronda 6.

---

## 4. Fase de construcción

### Mecánica base
- Cada jugador recibe **4 piezas aleatorias** al inicio de cada ronda — no se eligen, se reparten
- Tienes **30 segundos** para colocarlas donde quieras en el nivel
- Puedes colocar todas, algunas, o ninguna — las no usadas desaparecen
- Mientras construyes ves en tiempo real dónde colocan piezas los demás

### Categorías de piezas

#### Infraestructura
Plataformas, rampas, escaleras, puentes. No hacen daño. Son necesarias para que el nivel sea pasable.

**Tensión de diseño:** alguien tiene que sacrificar piezas en infraestructura o nadie puede avanzar — y el que pone infraestructura también se la regala a sus enemigos.

#### Trampas
Sierras giratorias, resortes de lanzamiento, pistones, pelotas que ruedan. Se activan con cualquier jugador.

**Regla clave:** si el constructor es lanzado encima de su propia trampa por otro jugador, la trampa lo mata igual. No hay inmunidad — solo hay distancia.

#### Modificadores
Zonas de gravedad reducida, superficies de hielo, ventiladores, zonas de rebote exagerado. No matan directamente — amplifican el caos físico de la fase de carrera. Son las piezas más impredecibles.

---

## 5. Fase de carrera

### Mecánica base
- Todos los jugadores aparecen en el punto de inicio al mismo tiempo
- El objetivo es llegar al punto final del nivel
- No hay tiempo límite — la ronda termina cuando todos llegaron o todos murieron
- El combate no pausa el avance — todo sucede en el mismo espacio al mismo tiempo

### Controles
**Correr · Saltar · Agarrar**

El agarrar es el verbo más importante. Puedes:
- Agarrar a otro jugador para lanzarlo
- Agarrar una superficie para no caer
- Agarrar una trampa para moverla ligeramente

Los controles son **intencionalmente imprecisos**. La imprecisión genera los momentos graciosos — es una decisión de diseño, no un bug.

### Mecánica de impulso acumulado
Si alguien te golpea y no caes, absorbes el impulso. El siguiente golpe que des lleva esa fuerza extra acumulada.

Crea momentos donde el jugador más golpeado se vuelve temporalmente el más peligroso — narrativamente interesante y visualmente gracioso.

### Física por personaje
La masa es variable por tamaño del personaje — no por stats explícitos:
- Personaje grande → más difícil de lanzar, más daño al caer
- Personaje pequeño → vuela más lejos, pesa menos al golpear

---

## 6. Sistema de puntos

Tres estrategias viables con el mismo sistema:

| Acción | Puntos |
|---|---|
| Llegar a la meta | +3 |
| Otro jugador muere con tu trampa | +1 por muerte |
| Eliminar a alguien en combate directo | +1 |
| Llegar último (pero llegar) | +1 bonus |
| Morir con tu propia trampa | −1 |
| No llegar y no matar a nadie | 0 |

### Las tres estrategias que esto genera
- **El corredor** — ignora a todos, llega primero, acumula puntos por meta
- **El trampero** — construye bien, llega tarde, acumula puntos por muertes ajenas
- **El peleador** — busca eliminar jugadores en combate directo, ignora la meta

En stream estas tres estrategias crean personajes naturales — el chat identifica rápido qué tipo es cada streamer.

---

## 7. Eventos de nivel

Cada dos rondas el juego lanza un evento que dura toda esa ronda. No los controlan los jugadores.

### Gravedad ligera
Todos saltan el doble de alto, los golpes lanzan más lejos, las trampas de rebote se vuelven letales. Las plataformas altas que nadie usaba se vuelven el campo de batalla principal.

### Turno nocturno
La visibilidad se reduce — solo ves claramente el área alrededor de tu personaje. Las trampas de rondas anteriores las recuerdas tú, los demás las descubren por accidente.

### Lluvia de piezas
Cada 10 segundos cae una pieza aleatoria del techo en posición fija. Nadie la colocó, nadie la controla. El nivel se vuelve más caótico de forma impredecible.

### El animal gigante
Un personaje NPC enorme y errático aparece en el nivel moviéndose sin lógica, chocando con todo. No tiene objetivo. Solo destruye el orden que todos habían calculado.

---

## 8. Personajes

Cuatro personajes base, todos animales antropomórficos con color sólido dominante. Ninguno tiene stats en pantalla — las diferencias son puramente físicas y de comportamiento ragdoll.

### El Gallo (rojo)
Cuerpo compacto y agresivo. Su centro de masa bajo lo hace difícil de derribar — absorbe golpes sin volar tan lejos. Referente visual inmediato, es el personaje que más se asocia con el combate directo.

### El Caballo (azul)
El más grande y pesado de los cuatro. Difícil de lanzar, hace más daño al caer sobre otros. Lento pero devastador en combate cuerpo a cuerpo. Sus extremidades largas le dan más alcance al agarrar.

### El Mapache (verde)
Pequeño y ligero. Los golpes que recibe lo lanzan más lejos de lo normal — es el más difícil de agarrar porque escapa por física, no por habilidad. Compensa con velocidad de movimiento.

### El Gato (morado)
Cuerpo muy deformable y flexible. Sus extremidades se doblan de formas inesperadas al agarrar superficies o personajes, creando situaciones físicas que ningún otro personaje puede replicar. El más impredecible de los cuatro.

---

## 9. Modos de juego

### Modo estándar
Lo descrito en este documento. 4 jugadores máximo, 6 rondas, nivel acumulativo.

### Modo traición
Uno de los jugadores es el **saboteador secreto**. Su objetivo es que nadie llegue a la meta — no que él llegue. Sus trampas no lo afectan a él. El resto no sabe quién es.

Fusiona social deduction con el gameplay base. Capa de paranoia que es oro para stream — el chat sabe quién es el saboteador antes que los jugadores.

### Modo speedrun
No hay fase de construcción. El nivel ya está construido (fijo o procedural) y todos compiten en puro tiempo. Más accesible para sesiones cortas y para jugadores nuevos.

---

## 10. Pros y contras del concepto

### Pros
- **Loop de contenido infinito** — la combinación de nivel construido por jugadores + física impredecible nunca produce el mismo resultado dos veces
- **Escalada orgánica de dificultad** — la complejidad visual crece con la tensión narrativa de forma natural
- **Rejugabilidad alta** — justifica el precio de Steam y genera sesiones largas
- **Clips que se crean solos** — ragdolls + trampas que fallan inesperadamente = contenido para TikTok/Shorts sin esfuerzo
- **Precio de compra impulsiva** — scope alcanzable, precio objetivo $8–$12, el viewer lo compra esa misma noche que lo ve en stream
- **Identidad visual clara** — animales cartoon con colores sólidos, siluetas legibles en el caos, un screenshot comunica el juego instantáneamente

### Contras
- **El netcode de física es el problema técnico más difícil del género** — sincronizar ragdolls con latencia variable es brutalmente complejo. Gang Beasts tuvo años de quejas por desyncs
- **El balance construcción/caos es frágil** — si las trampas son muy poderosas nadie pasa, si son muy débiles la fase de construcción se siente inútil. UCH tardó años de patches en encontrar ese balance
- **Riesgo de percepción derivativa** — los reviewers van a decir "es UCH + Gang Beasts" inmediatamente. El elemento propio (trampas sin inmunidad para el constructor, el impulso acumulado, la flexibilidad extrema del Gato) tiene que ser suficientemente visible
- **Requiere mínimo 3–4 jugadores para brillar** — limita la frecuencia de streams porque el streamer necesita amigos disponibles
- **La fase de construcción puede frenar el ritmo** — 30 segundos tiene que ser un límite duro, inapelable, o el stream se apaga

---

## 11. Decisiones de scope

| Decisión | Elección | Razón |
|---|---|---|
| Número de jugadores | **4 máximo** | Balance óptimo — cuatro estrategias claras, niveles manejables, netcode más simple |
| Conectividad | **Online multiplayer** | Usando **Steam Networking (Steamworks SDK)** — relay servers de Steam, NAT traversal incluido, sin infraestructura propia |
| Niveles | **Fijos, diseñados a mano** | Mejor experiencia por ronda, coherencia temática por sección de la juguetería, control total del balance de trampas |

### Implicaciones técnicas confirmadas

**Steam Networking** provee:
- Conexión P2P con relay de Steam como fallback
- NAT traversal automático — no requiere port forwarding del jugador
- Lobbies y matchmaking vía Steam lobbies API
- Sin costo de servidor dedicado — los jugadores alojan las sesiones

**Niveles fijos** implica:
- Cada nivel tiene su propio tema visual independiente — construcción, selva, ciudad, espacio, cocina — con sus propias piezas temáticas
- El número de niveles en lanzamiento define el contenido mínimo viable — recomendado: 8–10 niveles para Early Access
- Los niveles tienen que estar diseñados con la acumulación de piezas en mente — 6 rondas de construcción encima del mismo escenario no puede colapsar el nivel visualmente ni romper la jugabilidad

---

## 12. Stack técnico

### Motor — Godot 4.3+

Motor principal del proyecto. GDScript es Python-like — curva de aprendizaje mínima para alguien con experiencia en programación general. Exporta a Steam sin fricciones, es completamente gratis y sin royalties.

Desde Godot 4.2 usa **Jolt Physics** como motor de física integrado — significativamente más estable que el motor anterior, con soporte para comportamiento determinista necesario para sincronización online.

### Stack completo

| Capa | Herramienta | Rol |
|---|---|---|
| Motor | **Godot 4.3+** | Física, rendering, lógica de juego, escenas |
| Lenguaje | **GDScript** | Lógica principal (Python-like, aprendizaje rápido) |
| Física | **Jolt Physics** (integrado en Godot 4.2+) | Ragdoll, colisiones, sincronización determinista |
| Multiplayer | **Godot High-Level Multiplayer API** | Sincronización de estado con authority en host |
| Steam integration | **GodotSteam** | Lobbies, P2P networking, Steam achievements |
| Arte 3D | **Blender** | Modelado de personajes, piezas y niveles |
| Versionado | **Git + GitHub** | Control de versiones |
| Audio | **Godot AudioStreamPlayer** | Audio nativo para comenzar — migrar a FMOD si se necesita audio dinámico complejo |

### Por qué no los otros motores

**Unity** — descartado. Inestabilidad post-escándalo de pricing 2023 y su solución de netcode (Netcode for GameObjects + Unity Gaming Services) requiere infraestructura cloud de pago, lo cual contradice el uso de Steam Networking.

**Unreal Engine 5** — descartado. C++ en Unreal tiene su propio sistema de macros y convenciones que toman meses en dominar. Para un primer juego con física compleja y online multiplayer simultáneos es demasiado scope de aprendizaje.

### Arquitectura de red

El enfoque para sincronizar física ragdoll online es **no sincronizar la física directamente** — se sincronizan inputs y estado autoritativo desde el host, y cada cliente simula localmente.

```
Host (authority)
├── Recibe inputs de todos los clientes
├── Simula física de forma autoritativa
├── Envía estado de posición/rotación a todos
└── Resuelve conflictos de colisión

Cliente
├── Envía inputs al host
├── Simula localmente para responsividad inmediata
└── Reconcilia con el estado del host cuando llega
```

Esto requiere que la simulación de física sea **determinista** — Jolt lo soporta con configuraciones específicas que hay que activar desde el inicio del proyecto, no después.

### Primer prototipo — milestone de viabilidad

Antes de arte, niveles o modos de juego, el prototipo que valida el proyecto es uno solo:

> **Dos muñecos con física ragdoll sincronizados online entre dos clientes, con golpes que se sienten responsivos.**

Si ese prototipo funciona bien, el resto del juego es construible. Si la física se desincroniza o la latencia hace que los golpes se sientan raros, hay que resolver eso antes de agregar cualquier otra capa.

---

*Documento en desarrollo — siguiente paso: plan de prototipado y milestones de desarrollo.*
