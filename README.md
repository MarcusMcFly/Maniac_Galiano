# Maniac Galiano

Pruebas de concepto de cámara libre en tercera persona y exploración interactiva.

**Índice en vivo: [marcusmcfly.github.io/Maniac_Galiano](https://marcusmcfly.github.io/Maniac_Galiano/)**

## Formato elegido

Se experimentó con varios formatos y se eligió **este**: escena Three.js
estática, un único `index.html` que corre en el navegador sin build ni
plugins, con cámara libre en tercera persona y soporte de teclado/ratón y
táctil.

→ **[Ver POC 01](https://marcusmcfly.github.io/Maniac_Galiano/poc/)** — código en [`poc/`](poc/),
implementación de referencia de la `SPEC_01` y base técnica del formato: rig de
cámara con yaw/pitch, distancia preferida frente a real, colisión por
multi-raycast, fundido de paredes que se interponen, recentrado y modo órbita.

## Línea de trabajo: Digital Escape Room

Sobre ese formato se desarrolla **esta**, que es la que se trabajará como
Digital Escape Room:

→ **[Ver POC 04 — Cámara del Oro](https://marcusmcfly.github.io/Maniac_Galiano/poc04CO/)** — código en [`poc04CO/`](poc04CO/)

---

## poc04CO — Cámara acorazada explorable

Escena three.js (`index.html`) construida a partir del plano
[`01_c_o_map.png`](assets/references/01_c_o_map.png) (arriba = norte).

### Recorrido

Acceso principal → Control → Corredor → 1.ª bóveda → Vestíbulo blindado →
Recodo en zigzag → 2.ª bóveda → Pasillo perimetral → Cámara del oro.

Ramales:
- Galería de descenso (13 peldaños, -2,6 m) → Pozo/foso de seguridad
- Salida de servicio (este)

### Interacción

- 2 puertas de bóveda (disco 3,2 m, brazo de bisagra)
- 4 rejas dobles (cámara del oro)
- 3 puertas acorazadas rectangulares
- 5 armarios/taquillas

`F`: abrir/cerrar. Aviso: `[F] Abrir · <nombre>`.
`E`: coger objetos.
Hoja abierta no colisiona; no se cierra con jugador u objeto en el hueco.

### Oro

- 3.264 lingotes en 24 palés, una sola `InstancedMesh`.
- Colisión AABB por palé.
- 5 lingotes sueltos recogibles.

### Extras

Minimapa con estado de puertas, nombre de zona, texturas procedurales,
auto-escalón hasta 0,38 m.

### Verificación

Node + three.js con DOM/WebGL simulados, navmesh 2.5D:
- Puertas abiertas: 19/19 zonas alcanzables.
- Puertas cerradas: solo acceso, control y corredor.
- Cada barrera corta exactamente su zona.
- Corregido: pasillo tras las pilas (0,89 → 1,29 m); 2 objetos nacían dentro
  de un monitor y una taquilla.

### Pendiente

- [ ] Revisión visual (luz, materiales, cámaras): sin comprobar.
- [ ] Cerraduras y puzles sobre `openables` (`label`, `center`, `range`, `open`).
- [ ] Llaves candidatas: manojo de llaves, tarjeta de acceso, palanqueta, linterna.
- [ ] Definir la función del foso de seguridad (no documentada).

---

## Ejecutar en local

Las escenas Three.js usan módulos ES: **no funcionan con `file://`**, hay que
servirlas por HTTP.

```bash
python -m http.server 8000
# http://localhost:8000/poc04CO/
```

## Opciones descartadas

- **POC 02 — Godot 4.3 Web** ([`poc02/`](poc02/) · [demo](https://marcusmcfly.github.io/Maniac_Galiano/poc02/)).
  El mismo problema resuelto en Godot, con vertical slice completa (puzzle de
  llave, NPC, diálogo, guardado). Descartado: exige motor, export templates y
  build en CI frente a un `index.html` que se abre y ya.
- **POC 03 — Casa interactiva** ([`poc03threejs/`](poc03threejs/) · [demo](https://marcusmcfly.github.io/Maniac_Galiano/poc03/)).
  Misma técnica que la POC 01 aplicada a una vivienda. Descartada como
  escenario: el tema de casa no da pie al tipo de puzles del escape room.
