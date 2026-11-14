Put parashurama.glb in THIS folder (Assets/Models/parashurama.glb).
Open the project once so Godot imports it. Scenes/Player.tscn -> ModelRoot uses
Scripts/Player/CharacterModel.gd, which loads this file at runtime, auto-fits it to
1.8 m, and falls back to the procedural model if the file is missing.
Tune size / rotation / animation names on the ModelRoot node in the Inspector.
See README.md, section "Your glb character".

cave_lp.glb = baked cave for CaveRegion (see README "CAVE UPDATE"). Rebake with tools/bake_cave.py from the original Sketchfab file.
