Terrain textures
================
Phase 1 ships procedural textures (NoiseTexture2D resources) inside
Assets/Materials/terrain_material.tres, so there are no image files to import.

To use your own art (e.g. from Prisma3D or any paint app):
 1. Copy tileable PNG/JPG files into this folder.
 2. Open Assets/Materials/terrain_material.tres in the Godot inspector.
 3. Under "Shader Parameters" drop your texture on grass_tex / sand_tex /
    soil_tex / rock_tex / beach_tex.
 4. In the Import tab of each texture enable "Mipmaps > Generate" and re-import.
Tiling is controlled by the tile_scale parameter (tiles per metre).
