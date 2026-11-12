# PARASHURAMA - THE ORIGIN OF KERALA
### Phase 1: THE LOST AXE (open-world foundation)

A third-person mythological exploration game for Android, built with **Godot 4.7.x**, **GDScript only**, procedural geometry, no external assets, no plugins.

> **Story note:** the game is a *fictional retelling inspired by* the Kerala legend of Parashurama raising Kerala from the sea with his axe. The lost axe, the sanctum, the inscriptions and the Keeper are invented for the game and are not presented as history.

---

## STATUS - read this first

This project was written **without access to a Godot editor**. It has **not been opened or run in Godot**. What was verified:

* Static checks (`tools/validate_project.py`): every `res://` path in scenes/resources/scripts/project.godot exists, all `ExtResource`/`SubResource` ids are declared (sub-resources before use), no space indentation, balanced brackets, no duplicate functions, scene node paths used by `$Node` exist, JSON data parses.
* Manual review for Godot 4 API usage, typed GDScript (explicit types, no `:=` on Variants, `_`-prefixed unused parameters, `@warning_ignore("unused_signal")` on cross-script signals).

**Untested - expect a first-run fix pass:** script parse errors, shader compile errors, `.tres` loading, visual tuning (colours, scale, camera), physics feel, performance on real phones, touch control feel. If the Godot Android editor shows any error, paste the exact message and the file will be fixed.

---

## Quick start (Godot Android Editor)

1. Copy the project folder to your phone (or clone from GitHub).
2. In the Godot Android Editor choose **Import**, select `project.godot`.
3. First open imports nothing heavy (no image assets). Press **Play**. `Scenes/Main.tscn` is the main scene.
4. Check **Debugger > Errors** for anything red and report it.

Desktop/editor testing: WASD move, Shift run, Space jump, **E/F use**, Q/R rotate camera, mouse wheel zoom, right-mouse drag look, Esc pause. Mouse is also converted to touch, so the on-screen controls work with a mouse.

### Android export
Project > Export > Add **Android**. Set a package name (e.g. `com.yourname.parashurama`), enable **Gradle build off** (default template) unless you need it, orientation is already sensor-landscape, renderer is **Mobile**. `export_presets.cfg` is git-ignored because it can contain keystore paths; commit a sanitised copy when you set up GitHub Actions.

---

## How to play Phase 1

Left side: floating joystick (push to the edge to run). Right side: drag to look, pinch to zoom, **JUMP** and **USE** buttons. Top: objective + pause. Bottom: story notices and the current use prompt. Golden floating diamonds mark things worth examining.

Objective chain (`Data/quests.json`):

1. **Find the first clue to the missing axe.** Examine the drag marks on the beach.
2. **Challenge 1 - Hidden path.** Follow the mud trail into the forest; it ends at a wall of vines. Find the glowing carved tree off the trail (west). The vines part and lamps light the hidden path.
3. **Challenge 2 - Inscriptions.** Reach the Forgotten Sanctum. Collect three glowing fragments scattered on the plateau.
4. **Challenge 3 - Symbol puzzle.** Read the great tablet, then turn the three pillars (SEA, FOREST, MOUNTAIN, west to east).
5. Enter the opened sanctum, examine the altar -> final clue -> **"THE JOURNEY HAS JUST BEGUN..."**

---

## Architecture

```
project.godot            autoloads: GameInput, QuestManager, StoryManager
Scenes/                  Main, Player, World, Environment/{Coast,Forest,AncientRuins,Village},
                         Objects/{PalmTree,Rock,AncientClue}, UI/{GameHUD,MobileControls,PauseMenu,IntroCinematic}
Scripts/
  Core/        GameInput (actions + input bus), GameData (JSON), MeshBuilder (procedural meshes),
               GameMaterials (cached materials), Scatter (MultiMesh chunks/colliders), WorldRegistry
  Player/      PlayerController, CameraController, ParashuramaModel (replaceable)
  World/       WorldManager, TerrainGenerator
  Environment/ RegionBase + Coast/Forest/AncientRuins/Village regions, PalmTree, Rock, Vegetation, KeralaHouse, VineBarrier
  Objects/     Interactable, StoryInteractable, AncientClue, SymbolPillar
  Story/       QuestManager, StoryManager, IntroCinematic
  UI/          GameHUD, MobileControls, PauseMenu
Assets/Materials  terrain / ocean / foliage shaders + .tres materials (replaceable)
Assets/Textures   (procedural for now - see README.txt there)
Assets/Models     (for your Prisma3D exports)
Data/        quests.json, story.json (all narrative text), world_regions.json (map layout)
tools/       validate_project.py
```

Design notes:

* **Data driven.** Quests, all story text, region placement, trails, flatten zones and ground colouring live in `Data/*.json`.
* **Terrain** (`TerrainGenerator`): `height_at(x, z)` is a static pure function, so camera, scatter and regions can query ground height anywhere. One mesh per tile, trimesh collision. Vertex colours store splat weights (grass/sand/soil/rock) used by `terrain.gdshader`; shore wetness comes from height. The five textures are swappable shader parameters in `Assets/Materials/terrain_material.tres`.
* **Performance.** One draw call per palm/tree/house (vertex-coloured single mesh); vegetation uses chunked `MultiMeshInstance3D` with distance culling and a 2-level LOD for palms/trees; grass 55 m cull; shared materials/shapes; ocean without depth texture; Mobile renderer; pause menu has a Low graphics toggle (shadows off, 70% 3D resolution).
* **Player/model separation.** `PlayerController` only needs `$ModelRoot` to expose `update_motion(speed, grounded, delta)` (and optionally `reach_for_axe(duration)`).
* **Touch.** `MobileControls` converts touches to Input actions (`move_*`, `run`, `jump`, `interact`) - keyboard and touch share the same code path.
* **Input actions** are registered in code by the `GameInput` autoload (more robust than hand-written `project.godot` input maps).

### Replacing the character model
1. Export your Prisma3D model as `.glb` into `Assets/Models/`.
2. Open `Scenes/Player.tscn`, delete the script from `ModelRoot`, drag the glb in as a child of `ModelRoot` (face -Z, feet at y=0).
3. Optional: attach a small script to `ModelRoot` implementing `update_motion(speed, grounded, delta)` to drive your AnimationPlayer.

### Adding Phase 2+ regions (no rebuild of existing content)
1. Create `Scenes/Environment/DenseForest.tscn` whose root script `extends RegionBase` and overrides `_populate()` (use `add_trees`, `add_rocks`, ...).
2. In `Data/world_regions.json` fill in the already-reserved entry (`dense_forest`: set `scene`, `enabled: true`).
3. To grow the map, delete the relevant key from `terrain.bounds` (opens that edge) and add an entry to `terrain_tiles`. The placeholder entries for Phases 2-5 are already in the JSON.

### Known limitations
* No audio (no paid/external assets); ambient sound is a good next step.
* Characters/NPCs, combat, save/load not in Phase 1.
* Interior sanctum lighting is one omni light; no baked GI.
* Terrain textures are procedural noise (placeholder quality) - replace with your own.
