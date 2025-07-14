#!/bin/bash

# Script to launch the Voxel Animation Editor directly
# This bypasses the main VoxelWorld scene and opens the animation editor

echo "Starting Voxel Animation Editor..."

# Check if godot is available in PATH
if command -v godot >/dev/null 2>&1; then
    # Run the specific scene directly
    godot --path . VoxelAnimationExample.tscn
elif command -v godot4 >/dev/null 2>&1; then
    # Try godot4 if godot isn't available
    godot4 --path . VoxelAnimationExample.tscn
else
    echo "Error: Godot engine not found in PATH"
    echo "Please make sure Godot 4.x is installed and available as 'godot' or 'godot4'"
    echo "Alternatively, you can run this manually:"
    echo "  godot --path . VoxelAnimationExample.tscn"
    exit 1
fi