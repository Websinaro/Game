# Kerala Open World — Prototype 01

A small Godot 4 C# starter project for an Android-first Kerala village open-world game.

## Included in this first milestone

- Procedurally created green village ground and a road
- Simple Kerala-inspired houses and coconut trees
- Third-person capsule player
- Follow camera
- On-screen directional buttons for touch devices
- Keyboard movement for desktop testing

This is a greybox prototype: the buildings and trees are temporary shapes. We will replace them with Prisma3D models as the project grows.

## Important: C# and Godot on Android

This project targets **Godot 4.7.2 .NET** and .NET 8. The standard Godot Android Editor does not execute C# projects. You can keep the project in GitHub and use GitHub Actions to compile it, but you need a compatible Godot .NET editor/build workflow to run and export the C# game. Do not assume the regular Android editor can open this C# project.

## Create the GitHub repository from your phone

1. Open GitHub in your browser or app and sign in.
2. Tap **New repository**.
3. Name it `KeralaOpenWorld`.
4. Choose **Private** or **Public**, then create it.
5. Upload the contents of this ZIP to the repository root (upload the files and folders, not the ZIP itself).

## Version check before first build

The project is pinned to Godot 4.7.2 .NET. In your Godot app, open **About** or the version information and check whether it says **.NET**. If it is a different version, tell me the exact version before running the workflow; the project SDK and build workflow must match.

## Next milestone

After the first successful C# build, we will add a proper terrain layout, imported Prisma3D GLB assets, a better third-person camera, and mobile performance settings.
