# Valle de los Antiguos — contexto técnico para agentes (Hermes) y desarrolladores

Léelo antes de tocar nada. Resume cómo está construido el proyecto, qué se ha verificado y qué no.

## Estado de verificación (importante)
- **El código se escribió sin poder ejecutarlo en Godot.** Solo se validó con revisión estática (sintaxis, tipos,
  referencias entre scripts) y, para las poses de ataque, con una visualización en Python. Es esperable que la
  primera ejecución real muestre errores de ejecución. **Corregir esos errores es la primera tarea**, antes de
  cualquier plugin. Arreglar un error no es "modificar mecánicas".
- Motor objetivo: Godot 4.7.2 stable, Forward Plus, Windows x64. Solo GDScript (sin .NET).

## Flujo y estructura
- Escena inicial: `scenes/character_creation.tscn` (script `scripts/character_creation.gd`).
  "Comenzar aventura" → `GameState.new_game(ch)` → `scenes/main.tscn` (script `scripts/world.gd`, que monta todo).
- Autoload único: `GameState` (`scripts/game_state.gd`): personaje, nivel, XP, talentos, inventario, misiones,
  guardado (`user://personaje.json`, ruta cambiable con `save_path`) y señales (`leveled_up`, `inventory_changed`,
  `progress_changed`, `message`, `open_dialogue`). **Es la única fuente de verdad de los datos persistentes.**
- Mundo (todo por código, sin escenas editadas a mano): `terrain_generator.gd` (malla + colisión + camino),
  `ancient_ruins.gd`, `prop_scatter.gd` (+ `asset_catalog.gd`; árboles/rocas/hierba), `day_night.gd`, `world.gd`
  (NPC y enemigos), `world_data.gd` (zonas, NPC, campamentos).
- Jugador: `player.gd` (CharacterBody3D; cámara SpringArm3D propia; ataque; habilidades; recolección; interacción).
- Personajes: `character_actor.gd` carga el modelo `.glb`, comparte una librería de animaciones (`Rig_Medium`),
  **construye las animaciones `Attack_*` en tiempo de ejecución** y monta armas con `BoneAttachment3D`.
- Combate: `class_data.gd` (clases/armas), `progression_data.gd` (XP, talentos, 4 habilidades por clase),
  `combat_abilities.gd`, `ground_strike.gd`, `projectile.gd`, `combat_fx.gd`, `skeleton_enemy.gd`
  (IA: IDLE/WANDER/CHASE/RETURN; vida, estados, muerte y reaparición).
- Interfaz (todo por código): `hud.gd`, `inventory_panel.gd`, `talent_panel.gd`, `dialogue_panel.gd`.
- Datos: `item_data.gd`, `quest_data.gd`, `attack_data.gd` (**GENERADO** por `tools/export.py`; no editar a mano).
- Pruebas: `test/*.gd` (GdUnit4; los scripts no tienen `class_name` para no dar errores mientras el plugin no esté).

## Convenciones del código (respétalas)
- Sangría con **tabuladores**. Tipado estático donde sea posible.
- **Nunca `var x := <valor Variant>`** (diccionarios, variables sin tipo, `.get()`): Godot 4.7 lo rechaza.
  Usa `var x: Tipo = ...` o convierte (`String(...)`, `int(...)`, `as Tipo`).
- No redeclarar una variable local con el mismo nombre dentro del mismo ámbito.
- Los textos de la interfaz usan caracteres latinos; evita símbolos que la fuente por defecto no tenga (▶, ★, ✓).
- Mensajes y comentarios en español.

## Puntos de riesgo conocidos (comprobar primero en la primera ejecución)
1. `character_actor.gd`: nombres de pista de animación (`Skeleton3D:hueso`) y `root_node` del AnimationPlayer; que
   las `Attack_*` se creen (la consola imprime "Animaciones cargadas: N"; N debe incluir las 8 `Attack_*`: Slash, Chop, Stab, StabL, Cast, Bow, Aim1, Aim2).
2. Orientación/posición de las armas (`MOUNTS` en `attack_data.gd`) y que el modelo mire hacia -Z (rotación PI).
3. Shader de cambio de tono (`HUE_SHADER`) en la creación de personaje (colores de capa/sombrero).
4. Vista previa 3D (SubViewport) de la creación de personaje.
5. Barra de vida de los enemigos (quads con billboard) y números de daño (`Label3D`).
6. Máscaras de colisión: los rayos de proyectiles y de apuntado usan la máscara 1; el terreno y los troncos están en la capa 1.
7. HUD: anclajes de las barras de habilidades/XP en distintas resoluciones.
8. Recolección: `resource_node.gd` (encoger/respawn) sobre ~780 nodos; y el escaneo de interactuables cada 0,15 s.

## Mecánicas que NO existen todavía (registrar, no inventar sin pedirlo)
- Salud del jugador, daño del enemigo al jugador, muerte/reaparición del jugador.
- Botín de enemigos, tienda/comercio, crafting, equipo equipable (las armas se eligen solo al crear).
- Navegación con NavigationServer (los enemigos se mueven en línea recta; el terreno es una malla generada en
  ejecución, así que un navmesh habría que hornearlo en ejecución).
- Red/multijugador.

## Reglas de protección para cambios automáticos
- No reemplazar `player.gd`, `world.gd` ni `character_actor.gd` por completo: editar de forma mínima.
- No editar `attack_data.gd` a mano: regenerar con `tools/export.py` (ver README).
- Datos persistentes solo en `GameState`; no duplicar inventario/equipo/progreso en otro sistema.
- Probar antes/después cualquier cambio de física del jugador.

## Cómo ejecutar las pruebas (tras instalar GdUnit4 en `addons/gdUnit4`)
- En el editor: panel GdUnit4 → ejecutar `res://test`.
- Por línea de comandos (comprobar la sintaxis exacta en la documentación de la versión instalada), p. ej.:
  `Godot_v4.7.2-stable_win64_console.exe --path E:/GO/valle_de_los_antiguos -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://test`
- Las pruebas de GameState usan `user://test_personaje.json`; no tocan `user://personaje.json`.
