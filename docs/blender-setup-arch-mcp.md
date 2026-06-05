# Instalación de Blender en Arch + configuración de Blender MCP

Guía para dejar Blender funcionando en Arch Linux y conectado a Claude vía
**Blender MCP**, para poder modelar los personajes asistido por IA.

---

## Parte 1 — Instalar Blender en Arch

Blender está en el repositorio oficial `extra`, así que es directo:

```bash
sudo pacman -S blender
```

Verificar:
```bash
blender --version
```

> Alternativas si prefieres no tocar el sistema:
> - **Flatpak:** `flatpak install flathub org.blender.Blender`
> - **AUR (binario oficial):** `yay -S blender-bin` (versión exacta de blender.org)
>
> Para Blender MCP recomiendo la instalación normal de `pacman` (más simple de
> apuntar el addon). Cualquier Blender **3.0 o superior** sirve.

---

## Parte 2 — Instalar `uv` (gestor que corre el servidor MCP)

Blender MCP se ejecuta con `uvx` (parte de `uv`). En Arch:

```bash
sudo pacman -S uv
```

Verificar:
```bash
uv --version
uvx --version
```

> Si no estuviera en repos: `curl -LsSf https://astral.sh/uv/install.sh | sh`

---

## Parte 3 — Instalar el addon de Blender MCP

El proyecto Blender MCP tiene dos piezas: un **addon dentro de Blender** y un
**servidor MCP** que Claude lanza con `uvx`.

1. Descargar el addon (`addon.py`) del repositorio oficial:
   ```bash
   curl -L -o ~/Downloads/blender_mcp_addon.py \
     https://raw.githubusercontent.com/ahujasid/blender-mcp/main/addon.py
   ```
2. Abrir Blender → `Edit > Preferences > Add-ons > Install from Disk...`
3. Seleccionar `~/Downloads/blender_mcp_addon.py`
4. Activar la casilla del addon **"Interface: Blender MCP"**
5. En el viewport 3D, abrir la barra lateral con la tecla **N** → pestaña
   **"BlenderMCP"** → botón **"Connect to Claude"** (deja Blender escuchando en
   el puerto local que usa el servidor).

> El addon abre un socket local; el servidor `uvx blender-mcp` se conecta a él.
> Blender debe estar **abierto y con "Connect to Claude" activo** cuando trabajemos.

---

## Parte 4 — Registrar el MCP en Claude Code

Desde la raíz del proyecto, registrar el servidor (alcance de proyecto para que
quede en el repo y tu amigo también lo tenga):

```bash
claude mcp add blender --scope project -- uvx blender-mcp
```

Esto crea/actualiza un `.mcp.json` en el proyecto. Verificar:
```bash
claude mcp list
```

Debe aparecer `blender` y, al reiniciar la sesión de Claude Code, las herramientas
del MCP de Blender quedan disponibles.

> Alcances: `--scope project` lo guarda en `.mcp.json` (compartido por git).
> `--scope user` lo deja solo para ti en `~/.claude.json`.

---

## Flujo de trabajo una vez conectado
1. Abrir Blender → activar addon → **Connect to Claude**.
2. En Claude Code (esta sesión), las tools de Blender MCP estarán activas.
3. Trabajamos personaje por personaje siguiendo
   [`plan-personajes.md`](plan-personajes.md) y respetando el rig de
   [`blender-rig-spec.md`](blender-rig-spec.md).
4. Exportar `.glb` → yo lo importo en Godot y monto el ragdoll.

---

## Notas
- Blender MCP puede controlar Blender (crear/mover objetos, ejecutar Python del
  lado de Blender). Revisa lo que se ejecuta; trabajar sobre un `.blend` guardado
  para poder deshacer.
- Si el puerto del addon choca, en la pestaña BlenderMCP se puede cambiar.
- Mantener Blender y el addon en versiones compatibles (addon del mismo repo).
