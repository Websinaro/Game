# Kerala Open World — Prototype 02

A phone-first development project using Godot 4.7.2 .NET (C#).

## Current prototype
- Procedurally generated placeholder Kerala village
- Simple road, houses and coconut-tree placeholders
- Third-person capsule player and follow camera
- Basic keyboard movement actions (mobile touch controls are next)

## Requirements
- Godot 4.7.2 .NET edition
- .NET 8 SDK
- Matching Godot export templates for later exports

The standard Godot Android Editor cannot execute C# scripts. GitHub Actions can compile the project, but running and exporting it requires the matching .NET editor/build environment.

## Controls
The prototype registers these keyboard actions automatically:
- `move_left`: A / Left
- `move_right`: D / Right
- `move_forward`: W / Up
- `move_back`: S / Down
- `jump`: Space

## Next
Replace the placeholder house and palm geometry with GLB assets made in Prisma3D, then add on-screen mobile controls.
