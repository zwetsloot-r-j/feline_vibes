# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Godot 4.4 game project named "feline_vibes" - a minimal starting template with only the basic project configuration and default icon.

## Project Structure

- `project.godot` - Main Godot project configuration file
- `icon.svg` - Default Godot project icon (standard blue robot)

## Development Commands

Since this is a Godot project, development is primarily done through the Godot editor:

- Open the project in Godot Editor by opening `project.godot`
- Run the game: F5 in Godot Editor or `godot --path . --main-pack`
- Export builds: Use Godot Editor's Project → Export menu

## Architecture Notes

This is a fresh Godot project with no custom scripts, scenes, or resources yet. The project is configured for:
- Godot 4.4
- Forward Plus rendering
- Default project structure

When adding game code, typical Godot patterns include:
- Scripts in GDScript (`.gd` files) or C# (`.cs` files)
- Scenes in `.tscn` files
- Resources in various formats depending on type
- Assets typically organized in folders like `scenes/`, `scripts/`, `assets/`, etc.