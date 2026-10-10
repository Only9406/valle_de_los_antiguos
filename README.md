# Valle de los Antiguos — mundo inicial (Godot 4.2+)

Mundo jugable en tercera persona para tu MMORPG, con **creación de personaje**, **clases con armas**
y **combate con click**. Todo se genera por código; los assets de KayKit (CC0) ya vienen integrados.

## Puesta en marcha
1. Instala **Godot 4.2 o superior** (versión estándar, no .NET).
2. En Godot: *Import* → selecciona `project.godot` → **Abrir**.
3. **Espera a que termine de importar** los modelos (la primera vez tarda; barra abajo a la derecha).
4. Pulsa **F5**: arranca en la pantalla de creación de personaje.

## Flujo del juego
1. **Creación de personaje** (`scenes/character_creation.tscn`): nombre, **clase**, **arma**, **aspecto**
   y **color de prenda**, con vista previa 3D (arrastra para girar) que ejecuta el ataque del arma elegida.
   El personaje se guarda en `user://personaje.json`; la próxima vez aparece **Continuar**.
2. **Mundo** (`scenes/main.tscn`): plaza segura, bosque y cumbres con campamentos de esqueletos.
   Si ejecutas `main.tscn` directamente (F6) usa un Caballero por defecto.

## Controles
WASD mover · Shift correr · Espacio saltar · Ratón cámara · Rueda zoom ·
**Click izquierdo** ataque básico (mantenlo para repetir) · **1-4** habilidades · **E** hablar/recolectar ·
**I** inventario · **T** talentos · Esc libera el ratón / cierra paneles · **F1** vuelve a crear personaje.

## Clases y armas (assets KayKit Adventurers)
| Clase | Vida | Armas |
|---|---|---|
| Caballero | 160 | Espada y escudo · Espadón a dos manos |
| Bárbaro | 150 | Hacha y escudo · Gran hacha (área, 3 enemigos) |
| Mago | 90 | Bastón arcano (orbe violeta) · Varita y libro (fuego rápido) |
| Pícaro | 100 | Dagas gemelas (alternan manos) · Ballesta ligera |
| Explorador | 105 | Arco largo · Ballesta pesada |

- **Aspecto:** variantes por clase (con/sin casco, sombrero, capa; el Pícaro puede ir encapuchado).
- **Color:** 11 tonos aplicados a capa/sombrero/máscara mediante un shader de cambio de tono.
- **Cuerpo a cuerpo:** golpea a los enemigos en el arco frontal dentro del alcance (con ayuda de apuntado
  hacia el enemigo cercano). **A distancia:** dispara flechas/virotes/orbes hacia la mira (el punto del
  centro de la pantalla), con un pequeño autoenganche al enemigo más cercano a ella.
- Daño aleatorio entre mínimo y máximo, **críticos** (12 %, x1,8), números de daño flotantes y retroceso.

## Enemigos (Skeletons)
15 esqueletos en 5 campamentos. Tienen **vida** (Siervo 40, Pícaro 55, Mago 60, Guerrero 90), barra de vida
al ser dañados, reacción al golpe, **animación de muerte** y **reaparecen a los 25 s** en su campamento.
Te persiguen si te acercas o si los golpeas (la Plaza es zona segura). Al golpear a uno aparece su marco
arriba al centro. **Todavía no atacan al jugador** (ver siguientes pasos).

## Progresión, habilidades y talentos
- **Experiencia y nivel (máx. 20):** cada esqueleto da XP (Siervo 25, Pícaro 40, Mago 45, Guerrero 65) y las
  misiones también. Cada nivel da **+4 % de daño** y **1 punto de talento**. Barra de XP bajo las habilidades.
- **Barra de habilidades (1-4):** 4 por clase (20 en total), que se desbloquean en los niveles 1, 2, 4 y 6.
  Tipos: golpe frontal, área, embestida/salto, mejora temporal, proyectil, abanico de disparos y ataque de zona
  con retardo (Meteoro, Lluvia de flechas). Efectos: aturdir, ralentizar y veneno. Se definen en `progression_data.gd`.
- **Árbol de talentos (T):** 3 ramas × 3 filas (Combate, Maestría, Oficio). Cada fila se desbloquea al gastar
  3 puntos en su rama. Incluye daño, crítico, enfriamientos, velocidad, recolección más rápida/doble botín y XP extra.
  Puedes reiniciarlos gratis.
- Todo el progreso (nivel, XP, talentos, inventario, misiones) se guarda en `user://personaje.json`.

## Inventario y recolección
- **Inventario (I):** cuadrícula de 24 casillas con recursos (Madera, Piedra, Hierba) y herramientas.
- **Herramientas:** Hacha (árboles → madera), Pico (rocas → piedra) y Hoz (hierba → hierbas). Se equipan solas
  en la mano al recolectar. El hacha usa el modelo KayKit; el pico y la hoz son formas simples.
- **Recolectar:** acércate a un árbol, roca o mata de hierba y pulsa **E** (la barra de progreso aparece bajo la
  mira; moverte lo cancela). Cada árbol/roca da 3 recolecciones y reaparece a los 2 minutos; la hierba a 1 minuto.
- **Misión "Materiales para los Antiguos":** habla con el **Anciano Guardián** (plaza). Te da hacha, pico y hoz y te
  pide **10 maderas y 10 piedras**. Al entregarlas: 200 XP y 1 punto de talento. El seguimiento sale arriba a la derecha.

## Estructura
- `scripts/class_data.gd` — **clases, armas, aspectos y colores** (añade contenido aquí).
- `scripts/progression_data.gd` — **XP, talentos y habilidades** de cada clase.
- `scripts/item_data.gd`, `quest_data.gd` — objetos, nodos recolectables, misiones y diálogos.
- `scripts/combat_abilities.gd`, `ground_strike.gd` — lógica de las habilidades.
- `scripts/resource_node.gd`, `tool_models.gd` — recolección y modelos de herramientas.
- `scripts/inventory_panel.gd`, `talent_panel.gd`, `dialogue_panel.gd` — paneles de la interfaz.
- `scripts/character_creation.gd` — pantalla de creación + vista previa 3D.
- `scripts/game_state.gd` — autoload: personaje, nivel/XP, talentos, inventario, misiones y guardado.
- `scripts/character_actor.gd` — modelo + animaciones + armas + color (héroes y esqueletos).
- `scripts/attack_data.gd` — **generado**: animaciones de ataque y montaje de armas (ver abajo).
- `scripts/player.gd` — movimiento, cámara, ataque, daño y proyectiles.
- `scripts/skeleton_enemy.gd` — IA, vida, muerte y reaparición.
- `scripts/projectile.gd`, `combat_fx.gd` — proyectiles, números de daño y destellos.
- `scripts/hud.gd` — mira, panel del héroe, marco del objetivo y barra de recarga.
- `scripts/world.gd`, `world_data.gd`, `terrain_generator.gd`, `ancient_ruins.gd`, `prop_scatter.gd`… — mundo.
- `tools/` — generador de las animaciones de ataque (Python).

## Animaciones de ataque
Los packs gratuitos de KayKit **no incluyen animaciones de ataque**, así que se generan con cinemática
inversa (brazo de 2 huesos + torsión del torso + orientación del arma) sobre el rig `Rig_Medium`, y se
exportan a `scripts/attack_data.gd`. En el juego se construyen como `Attack_Slash`, `Attack_Chop`,
`Attack_Stab`, `Attack_StabL`, `Attack_Cast`, `Attack_Bow`, `Attack_Aim1` y `Attack_Aim2`.
Para retocarlas: edita `tools/attacks.py` y ejecuta (con `numpy` y `matplotlib`)
`KAYKIT_ADVENTURERS=ruta/al/pack python tools/attacks.py` (genera hojas de poses para revisar) y
`... python tools/export.py` (regenera `attack_data.gd`). Cuando compres/uses un pack con animaciones de
combate reales, sustituye por ellas en `class_data.gd` (campo `attack`).

## Ajustes rápidos
- **Nueva arma/clase:** añade una entrada en `class_data.gd` (usa cualquier `.gltf` de `assets/kaykit_adventurers/props`).
  Si es un arma nueva con orientación propia, añádela a `WEAPONS` en `tools/design.py` y regenera.
- **Daño/alcance/cadencia:** campos `dmg`, `range`, `cooldown` y `targets` de cada arma. Crítico: `crit_chance` en `player.gd`.
- **Vida de enemigos / reaparición:** `HP_BY_KIND` y `RESPAWN_TIME` en `skeleton_enemy.gd`.
- **Campamentos:** `CAMPS` en `world_data.gd`.

## Notas
- Si un arma se ve mal orientada o un personaje de espaldas, ajusta `model.rotation.y` o el montaje
  en `attack_data.gd` / `tools/design.py` (función `mount`).
- No he podido ejecutar el proyecto en un Godot real durante el desarrollo: las poses de ataque se
  validaron con una visualización en Python y el código con revisión estática. Si ves algún fallo, la
  consola de Godot indicará el script y la línea.

## Siguientes pasos hacia MMO
- Que los enemigos contraataquen y el jugador tenga vida, muerte y reaparición.
- Botín de enemigos, tienda del mercader (vender hierbas/materiales) y más misiones (cadenas de misiones).
- Red: `ENetMultiplayerPeer` + `MultiplayerSpawner`/`MultiplayerSynchronizer`, servidor autoritativo
  (el daño y la vida de los enemigos ya están centralizados en `skeleton_enemy.gd`).

## Créditos
Modelos de **Kay Lousberg** (www.kaylousberg.com), licencia CC0. Ver `assets/CREDITS.md`.
