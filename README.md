# PARASHURAMA - THE ORIGIN OF KERALA
### Phase 1: THE LOST AXE (open-world foundation)

A third-person mythological exploration game for Android, built with **Godot 4.7.x**, **GDScript only**, procedural geometry, no external assets, no plugins.

> **Story note:** the game is a *fictional retelling inspired by* the Kerala legend of Parashurama raising Kerala from the sea with his axe. The lost axe, the sanctum, the inscriptions and the Keeper are invented for the game and are not presented as history.

---

## STATUS - read this first

This project was written **without access to a Godot editor**. It has **never been opened or run in Godot**, and **your `parashurama.glb` was not in the upload** (only the project zip arrived), so the model loader could not be tested against your real file. See **"Tested vs untested"** at the bottom for the honest list. If the Godot Android editor shows any red error, paste the exact message and the file gets fixed.

## What changed in this update (v3: trees and grass everywhere)

New `Scripts/Environment/WorldVegetation.gd`, called from `WorldManager.build_world()` after all regions. It spreads your
coconut palms (`coconut_tree_low_poly.glb`), forest trees (`forest_trees.glb`) and grass (`realtime_grass.glb`) over ALL land,
not just the forest / coast / village circles. Palms are more likely near the sea and in low ground, broadleaf trees inland.
Palms come in natural groups with a slight lean, fallen coconuts lie under them, bushes and grass fill the rest.
Tweak the constants at the top of that file (`TREE_SPACING`, `GRASS_SPACING`, draw distances). Not yet run in Godot.

## What changed in this update (v2)

1. **Fixed joystick** - `Scripts/UI/MobileControls.gd`. Constants at the top: `JOY_MARGIN_LEFT`, `JOY_MARGIN_BOTTOM`, `JOY_RADIUS`, `KNOB_RADIUS`, `JOY_TOUCH_RADIUS_MULT` (touch must start within radius x this), `DEAD_ZONE`, `RUN_THRESHOLD`.
2. **Graphics** - rewritten `terrain.gdshader`, `ocean.gdshader`, `foliage.gdshader`, richer procedural textures (+ `detail_tex`, `macro_tex`), new sky/fog/sun values in `WorldManager`, denser grass with distance fade, real Low/High switch (see cost table).
3. **GLB character** - `Scripts/Player/CharacterModel.gd` on `$ModelRoot`; procedural model stays as fallback. `tools/inspect_glb.py` prints size/animations/textures of a glb on a PC.
4. **Tougher game** - stamina, deep water, harder puzzle, hidden beacons, slippery slopes, falling rocks, dark sanctum + lamps, Normal/Hard selector. Every number is in `Scripts/Core/Tuning.gd`.

New files: `Scripts/Core/Tuning.gd`, `Scripts/Core/GameSettings.gd` (autoload), `Scripts/Player/CharacterModel.gd`, `Scripts/Environment/RockfallZone.gd`, `tools/inspect_glb.py`. Changed: `project.godot` (GameSettings autoload, soft shadow quality), `Data/quests.json` (+`light_lamps` Hard-only step, `*_hard` fields), `Data/story.json` (Hard riddle templates and lore variants), plus the scripts listed in each section below.

---

## 1. Fixed joystick
Always drawn bottom-left (base, run ring, dead-zone ring, knob). A touch only grabs the stick if it begins within `JOY_RADIUS * JOY_TOUCH_RADIUS_MULT` of the base. Knob clamps to the radius; radial dead zone with rescaling; pushing past `RUN_THRESHOLD` presses `run` (the player ignores it while tired). Jump / Use / camera drag / pinch are unchanged and independent touches, so stick + camera + jump work together. Mouse works in the editor through `emulate_touch_from_mouse`.

## 2. Graphics and expected cost
All costs below are **estimates from reading the shaders, not measurements**. Profile on your phone.

| Change | Cost (High) | Notes |
|---|---|---|
| Terrain: height-blended layers (ragged grass fringe, rock cracks) | small ALU | High only |
| Terrain: macro colour variation + detail texture | +2 texture reads | High only |
| Terrain: triplanar rock + strata on steep slopes | +2 reads | High only; Low uses 1 read |
| Terrain: derivative bump shading | small ALU, 2x2-quad noise at distance | High only; tune `bump_strength` |
| Terrain: wet-sand shoreline, tide band, specular | tiny | both |
| Terrain total | about 9 reads High, 5 reads Low (old shader: 7) | Low is cheaper than before |
| Ocean: depth colour + shoreline foam + wash lines without depth texture | small ALU | uses an analytic beach profile; update `shore_*` uniforms if you change `TerrainGenerator.height_at` |
| Foliage: wind gusts, per-plant tint, backlight | small ALU | High only |
| Grass: +50% density, sinks into ground between 36-52 m | vertex cost up, but capped by the 55 m cull | Low: 20-30 m |
| Sky/fog/ACES-free filmic + saturation/contrast adjustment | about 0 | adjustment turned off on Low |
| Soft shadows (project setting quality 2, blur 1.3, blended splits) | small | off on Low |
| MSAA 2x | moderate on some GPUs | off on Low |
| **Low graphics** | shadows off, MSAA off, 70% resolution, vegetation ranges x0.7 (grass x0.55), simpler shaders, more fog | the biggest win is resolution + shadows |

Textures stay replaceable: `Assets/Materials/terrain_material.tres` (grass/sand/soil/rock/beach/detail/macro), ocean and foliage parameters are in their `.tres`. Draw calls are unchanged (MultiMesh chunks, shared materials). Look values (colours, fog, sun) are constants at the top of `WorldManager.gd`.

## 3. Your glb character
1. Copy `parashurama.glb` to `Assets/Models/` (the exact name; or change `model_path` on `ModelRoot`). Open the project so Godot imports it.
2. `ModelRoot` (script `CharacterModel.gd`) loads it at runtime. If the file is missing or fails to load you get a red error in the Output panel and the procedural model is used.
3. **Auto-fit:** measures all meshes, scales to `target_height` (1.8 m), puts the feet at y = 0, centres x/z, applies `yaw_degrees` (default **180**, because glTF models face +Z and Godot forward is -Z). **If he walks backwards set yaw to 0.** If he lies on his back, `auto_fix_z_up` handles Z-up exports. Extra tweaks: `scale_multiplier`, `manual_offset`.
4. **Animations:** looks for an `AnimationPlayer`; maps idle/walk/run/jump/reach by exact name or keyword (`idle|stand`, `walk`, `run|sprint|jog`, `jump|leap|air|fall`, `reach|axe`). Crossfades with `blend_time`, scales walk/run speed to ground speed. Missing walk uses run and vice versa. States with no animation get a procedural bob/lean/sway. No `AnimationTree` is used (a code-built tree is hard to verify blind).
5. **Reach for axe:** plays a `reach` animation if found; else rotates the right upper-arm bone (auto-detected, or set `right_arm_bone_hint`; flip `reach_arm_sign` if the arm swings the wrong way) plus a body lean; else lean only.
6. **Report:** on start the Output panel prints bounds, scale used, triangle count, largest texture, bones, animation names/lengths and the mapping. Textures above 2048 px give a warning: use the Import tab (Size Limit, VRAM compression, Mipmaps). Shadows are forced on for all model meshes.
7. On a PC: `python3 tools/inspect_glb.py parashurama.glb` prints the same facts before importing.

## 4. Difficulty
Pause menu: **Difficulty Normal / Hard** (saved in `user://settings.cfg`). Stamina, water, slopes, rockfall and beacons react at once; puzzle layout, fragment positions and the sanctum lamps are built when the world is built, so they change after **Restart**.

| Feature | Normal | Hard |
|---|---|---|
| Stamina bar (run drains, tired state, slower, weaker jump) | generous | short, slow regen |
| Deep water: slows, current pushes back, cannot pass a depth limit | 1.3 m | 0.9 m, stronger current |
| Slippery slopes (floor angle) | from 32 deg | from 26 deg, faster slide |
| Falling rocks on the hidden path (red warning disc, shove + stamina loss, no damage) | slow, big warning | fast, wide |
| Puzzle | 3 pillars fixed order, wrong answer resets and locks 3 s | **5 symbols in a random order each playthrough**, 5 fragments with relative clues in shuffled reading order, wrong answer locks 12 s |
| Fragments | no beacon | no beacon, hidden among 10 spots (5 used) |
| Guide beacons | on (not on fragments) | all hidden; dim tree sigil; smaller tree radius; vaguer beach clue |
| Sanctum | lit | **dark; new objective "Light the three lamps"**; altar only after |

Tune everything in `Scripts/Core/Tuning.gd` (`*_NORMAL` / `*_HARD` pairs). Quest data: `Data/quests.json` supports `text_hard`, `required_hard`, `notify_hard` and `"hard_only": true` objectives. Story: any lore id can have a `<id>_hard` variant.

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

Left side: fixed joystick (push to the edge to run; the stamina bar appears top-left). Right side: drag to look, pinch to zoom, **JUMP** and **USE** buttons. Top: objective + pause. Bottom: story notices and the current use prompt. Golden floating diamonds mark things worth examining.

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
* **Performance.** One draw call per palm/tree/house (vertex-coloured single mesh); vegetation uses chunked `MultiMeshInstance3D` with distance culling and a 2-level LOD for palms/trees; grass 55 m cull; shared materials/shapes; ocean without depth texture; Mobile renderer; pause menu has Low/High graphics and Normal/Hard difficulty.
* **Player/model separation.** `PlayerController` only needs `$ModelRoot` to expose `update_motion(speed, grounded, delta)` (and optionally `reach_for_axe(duration)`).
* **Touch.** `MobileControls` converts touches to Input actions (`move_*`, `run`, `jump`, `interact`) - keyboard and touch share the same code path.
* **Input actions** are registered in code by the `GameInput` autoload (more robust than hand-written `project.godot` input maps).

### Replacing the character model
See section 3 above (`CharacterModel.gd`). Any other model only needs a Node3D under `$ModelRoot` with `update_motion(speed, grounded, delta)` and optional `reach_for_axe(duration)`.

### Adding Phase 2+ regions (no rebuild of existing content)
1. Create `Scenes/Environment/DenseForest.tscn` whose root script `extends RegionBase` and overrides `_populate()` (use `add_trees`, `add_rocks`, ...).
2. In `Data/world_regions.json` fill in the already-reserved entry (`dense_forest`: set `scene`, `enabled: true`).
3. To grow the map, delete the relevant key from `terrain.bounds` (opens that edge) and add an entry to `terrain_tiles`. The placeholder entries for Phases 2-5 are already in the JSON.

### Known limitations
* No audio (no paid/external assets); ambient sound is a good next step.
* Characters/NPCs, combat, save/load not in Phase 1.
* Interior sanctum lighting is one omni light; no baked GI.
* Terrain textures are procedural noise (placeholder quality) - replace with your own.

## Export an APK (Godot Android editor)
1. Project > Install Android Build Template is **not** needed (Gradle build off).
2. Project > Export > Add > Android. Set Package/Unique Name (e.g. `com.yourname.parashurama`), Min SDK 24+, tick ARM64 (arm64-v8a), untick x86.
3. Create a debug keystore when asked (Editor Settings > Export > Android) or use release keystore for Play.
4. Make sure the renderer is Mobile (already set) and `Assets/Models/parashurama.glb` is imported (export includes it automatically).
5. Export Project (APK) and install. `export_presets.cfg` is git-ignored.

## Tested vs untested
Tested here (static, no Godot available):
1. `tools/validate_project.py` passes with 0 errors / 0 warnings: all `res://` paths exist, ext/sub resource ids declared before use, brackets and tab indentation balanced, no `:=` on Variant sources, no `const` Packed arrays, no signal named `notification`, every `Tuning.X` exists, every `shader_parameter` in a `.tres` is a real uniform, objective ids used in scripts exist in `quests.json`, JSON parses. The validator itself was tested by injecting four known mistakes, all caught.
2. `tools/inspect_glb.py` ran correctly on a synthetic glb I generated (box + one animation).
3. Fragment hiding spots and sanctum lamp spots were checked against the ruin collider boxes in a small script (approximate, ignores rotation).
4. Puzzle clue logic checked on paper: the five Hard clues fix a unique order.

NOT tested (everything that needs the Godot engine):
5. That any script parses and runs in Godot 4.7; GDScript warnings-as-errors; shader compilation (terrain, ocean, foliage); `.tres` loading (noise texture properties such as `domain_warp_*`).
6. The glb: loading, auto-fit height/pivot/yaw, animation mapping, blending, reach-for-axe arm rotation (axis/sign guessed), shadows, texture sizes. **Your glb was not available.**
7. Joystick feel on a real phone; multi-touch; emulated touch in editor.
8. Visual quality and tuning of textures, bump, foam, sky, fog, tone; all performance numbers (estimates only).
9. Stamina/water/slope/rockfall feel and balance; `floor_stop_on_slope` with the slide push; rock impact timing; the dark-sanctum vignette; lamp placement.
10. Difficulty save/load, restart behaviour, HUD stamina bar layout.

API points I was not 100% sure of and chose conservatively: `AnimationPlayer.pause()`, `Skeleton3D.reset_bone_pose()`, `BACKLIGHT` in the Mobile renderer (harmless if ignored), `GradientTexture2D` radial fill for the darkness vignette, `Viewport.msaa_3d` switching at runtime. If one errors, the message names the line.


## Dynamic sun and sky (cinematic lighting upgrade)

The `DayNightCycle` autoload keeps a persistent 24-hour clock across scene changes.
A complete in-game day lasts 20 real-time minutes and begins at 08:00. The directional
sun moves gradually through the sky; its elevation, azimuth, colour and energy change
through morning, midday, evening and night. Procedural sky colours, ambient energy and
fog colour follow the same clock. The sun transform updates every frame, while sky and
ambient material values update twice per second to limit mobile rendering overhead.

The existing High/Low graphics quality settings and shadow configuration are retained.
This is a first implementation and should be visually and thermally tested on target
Android devices before release.


## Region-aware atmospheric lighting upgrade

WorldManager now blends mobile-friendly non-volumetric exponential fog profiles as
the player moves between the coast, forest, village and ancient ruins. Profiles tune
fog density, low-altitude height haze, sun scattering, aerial perspective and fog/sky
interaction. DayNightCycle retains ownership of time-of-day fog colour and applies the
current region tint, so region transitions and the day/night cycle remain coordinated.

The forest profile uses stronger low-altitude haze and sun scattering to suggest humid
forest mist and sunlight piercing canopy gaps. Coast uses clearer air with subtle
marine haze; village uses warm, light atmospheric depth; ruins use slightly denser,
dust-warm haze. Profile changes are smoothly blended.

This project uses Godot's Mobile renderer. Godot 4.7 volumetric fog is not supported
by Mobile or Compatibility renderers, so this implementation intentionally uses
non-volumetric fog. Sun scattering creates an atmospheric sun glow, not physically
accurate volumetric god-ray shafts. True volumetric shafts would require a different
rendering path or a custom low-cost approximation and must be evaluated separately.


## Forest realism upgrade

The Whispering Grove now creates a small set of soft-edged, animated mist cards and subtle directional light-shaft cards. The effects are local to the Forest region and respond to the adaptive graphics preset:

- LOW: 2 mist layers, no shaft cards.
- MEDIUM: 4 mist layers, 1 shaft card.
- HIGH: up to 6 mist layers, 3 shaft cards.

These are lightweight transparent shader approximations for the Mobile renderer, not volumetric fog or physically simulated god rays. They do not add real-time lights or shadow casters. Test transparency sorting and overdraw on target Android devices.

---

## CAVE UPDATE - Phase 1 cave integration (entrance + inside)  [NOT yet run in Godot]

The hidden path now ends at **The First Cave** instead of the old sanctum. New story chain (`Data/quests.json`, quest `lost_axe`):

1. `find_marks` -> 2. `hidden_path` (god tree opens the vines) -> **3. `stones`** find the SEA, FOREST and MOUNTAIN stones lying around the cave (3/3)
-> **4. `door`** set them in the three hollows of the stone door in the right order -> the door sinks open
-> **5. `pantham`** go into the dark first chamber and take the pantham (torch; a faint ember glow shows where it is)
-> **6. `altar`** follow the passage through the neck into the second chamber, the **station**; its relief says this is only the beginning of the four trials still to come -> "THE JOURNEY HAS JUST BEGUN..."

Right order on the door (left to right): SEA, FOREST, MOUNTAIN. The carved stele beside the plaza gives it as a riddle. A wrong full set shakes the door, resets the sockets and locks them 3 s (Normal) / 10 s (Hard).

### New / changed files
| File | What |
|---|---|
| `Assets/Models/cave_lp.glb` | your cave, cleaned and baked (see below) |
| `Scripts/Environment/CaveRegion.gd`, `Scenes/Environment/Cave.tscn` | the region: cave shell + collision, door, plaza, stones, stele, pantham, station, darkness |
| `Scripts/Objects/CaveStone.gd`, `StoneSocket.gd`, `PanthamPickup.gd`, `PanthamTorch.gd` | interactables and the carried torch (flickering OmniLight on the player's ModelRoot) |
| `Data/world_regions.json` | `ancient_cave` enabled, `ancient_ruins` disabled (set `enabled` back to true to restore it) |
| `Data/quests.json` | `lost_axe` rewritten; the old chain is kept as `lost_axe_sanctum` |
| `Data/story.json` | stone, door, stele, pantham and station texts; new phase-complete text |
| `Scripts/Core/Tuning.gd` | `CAVE_*` numbers (darkness, torch range/energy, lockout; Normal/Hard pairs) |
| `Scripts/World/WorldManager.gd` | `ancient_cave` fog profile |
| `tools/bake_cave.py`, `tools/validate_project.py` | cave baker; validator now reads objective ids from all quests |

### How the cave model was prepared (`tools/bake_cave.py`)
Your `cave_lp` file is one closed bumpy volume of **two chambers joined by a narrow neck** (about 3 x 3 x 6 model units, 18k triangles). It has no floor, so it cannot be walked on as it is. The baker: applies the glTF rotation, turns it so the doorway faces +Z, adds a **flat walkable floor** from the cave outline at one height, drops everything under it, cuts an **arched doorway** in the front wall, and writes one GLB (12.7k + 349 triangles, the original 3 textures). Collision is a trimesh built from the same faces at game scale (backface collision on). Scale in game: `CaveRegion.CAVE_SCALE = 4.5` (first chamber about 10 m wide and 5 m high, neck about 3 m wide, whole cave about 26 m long). The player is 2.4 m tall in this project, so do not go much below 4.
`cave_on_an_alien_planet_skybox` is **not used**: it is a 16 MB sphere with a 4k texture and an alien sky; it does not fit an enclosed mobile cave. Tell me if you want it as a distant backdrop anyway.

### Darkness and light
Inside the cave `CaveRegion._process` drives the existing HUD vignette (`GameInput.darkness_changed`): 0.97 before the pantham, `CAVE_DARK_TORCH_*` after. The pantham adds a real `OmniLight3D` to the player (no shadows, mobile friendly). The sun and sky still light the cave walls in the engine, so the vignette does most of the work, the same trick the old sanctum used.

### Tested vs untested (be honest with yourself before you ship)
Tested here: `tools/validate_project.py` passes with 0 errors; the baked GLB was checked structurally (header, chunk sizes, accessor ranges, index bounds, no NaN, normals unit length) and with rays against the mesh (the doorway is open at walking height, the lintel is closed, the floor slice is one connected peanut shape, neck about 0.7 u = 3 m wide, ceiling 1.2 u = 5.4 m in chamber one and 0.8 u at the neck).
NOT tested (no Godot here): any of the GDScript running; the GLB importing in Godot 4.7; the doorway/door slab looking right (the slab stands just in front of the arch and is sized by guess); collision feel in the neck; camera clipping inside the cave; stone/door positions on the plateau; the darkness level; performance on a phone. If something is red in Debugger > Errors, paste it and it gets fixed.

Things most likely to need a number change: `CaveRegion.CAVE_SCALE`, `DOOR_*`, `DOOR_Z`, `STONE_SPOTS`, `PANTHAM_SPOT_U`, `STATION_SPOT_U`, `SIGIL_ROW_Z_U` (all constants at the top of that file).

### Phase 2 hardening - already prepared
`CaveRegion.SOLUTION` is one constant (make it a random permutation and generate the stele text from `Data/story.json`), `Tuning.CAVE_*` already have Hard values, `StoneSocket` / `CaveStone` / `PanthamPickup` are small separate scripts, and `quests.json` supports `*_hard` fields. See the chat for the proposed hard clues.
