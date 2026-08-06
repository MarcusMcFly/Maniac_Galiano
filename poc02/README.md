# POC02 — Godot Web Free-Camera Vertical Slice (SPEC_02)

POC independiente del POC Three.js (`poc/`), según `docs/SPEC_02_godot_web_free_cam_poc.docx`.

## Ejecutar

1. Abrir con **Godot 4.3+ estable** (renderer Compatibility ya configurado): importar esta carpeta como proyecto y pulsar F5.
2. Export Web: instalar las export templates y ejecutar
   `godot --headless --path . --export-release "Web" build/web/index.html`
   El resultado es estático y sirve en GitHub Pages (WEB-001..004).

## Qué incluye (vertical slice §4.1)

- **Lobby + pasillo con estrechamiento + 3 salas** (una cerrada con llave) + **escalera con rellano**.
- **Jugador** `CharacterBody3D` con `move_and_slide`, movimiento relativo a cámara (PLY-001/002).
- **Cámara libre**: rig YawPivot→PitchPivot→`SpringArm3D`(SphereShape, margin, máscara dedicada)→`Camera3D`; zoom con distancia preferida/real, recentrado con R (CAM-GD-001..005).
- **Oclusión**: raycast independiente del spring; solo el grupo `camera_fadeable` se funde, con histéresis y materiales por instancia; la colisión persiste (OCC-001..006).
- **RoomVolumes** `Area3D` con `CameraProfile` (Resource) por sala, blending suave y política de techos (ROOM-001..003, OCC-005).
- **6 interactuables** (tabla 12.1): llave → inventario, puerta cerrada (usar llave, abrir/cerrar, cambia colisión), interruptor → `OmniLight3D`, foto → **inspección en SubViewport** rotable (INS-001..003), máquina expendedora con audio, escalera con modo cámara TRANSITION.
- **Puzzle completo** (INT-005): encontrar llave → inventario → abrir puerta → sala C, persistido en guardado.
- **NPC** `NavigationAgent3D` sobre navmesh bakeado en runtime, estados IDLE/WALK/TALK/RETURN, sin jitter al llegar (NPC-001..004).
- **Diálogo** con opción condicionada por inventario y mutación de flag; cámara de diálogo y restauración (DIA-001..003).
- **Guardado** en `user://` con `schema_version`, aviso si el almacenamiento no es persistente, F10 reset determinista (SAVE-001..004, DBG-005).
- **Audio**: buses Master/Music/SFX, arranque solo tras gesto del usuario, ambiente + pasos + 2 fuentes posicionales, WAV generados proceduralmente (AUD-001..005).
- **HUD**: prompt contextual, inventario, panel de diálogo, overlay de inicio, overlay de debug (FPS, sala, distancias, modo cámara).

Controles: WASD · ratón · rueda zoom · R recentrar · E interactuar · I/Tab inventario · F5/F9/F10 guardar/cargar/reset · Esc soltar ratón.

## Desviaciones documentadas respecto a la SPEC

- **Composición por código, no por .tscn**: el blockout y la UI se construyen en `main.gd`/`hud.gd` para que el POC sea revisable y versionable como texto. La migración a PackedScenes/inspector es el paso natural en el editor (§5 queda parcialmente diferido).
- **Sin GLB ni AnimationTree** (ANIM-001..005): personajes primitivos sin animación esquelética; requiere assets de Blender.
- **Sin gamepad ni táctil** (INP-003/004): stretch goals pendientes.
- **CI de despliegue** (WEB-006): `.github/workflows/deploy-godot-pages.yml` en la raíz del repo exporta este proyecto con Godot 4.3 pineado y publica `/poc/` y `/poc02/` en GitHub Pages en cada push a `main`.
- **AudioSnapshot/Theme/settings UI** (§16 UI-003): pendientes de la fase 5.

## Estructura

- `scenes/main.tscn` — escena raíz mínima.
- `scripts/main.gd` — mundo, salas, navegación, interacción, audio.
- `scripts/player.gd` — controlador + rig de cámara + fundido de oclusión.
- `scripts/interactable.gd` — contrato de interacción (6 tipos vía `kind`).
- `scripts/npc.gd` — navegación + máquina de estados + datos de diálogo.
- `scripts/hud.gd` — UI por código (Control nodes), inspección SubViewport.
- `scripts/game_state.gd`, `scripts/save_service.gd` — autoloads.
- `scripts/camera_profile.gd` — Resource de perfil de cámara.
