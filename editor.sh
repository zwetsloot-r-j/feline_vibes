#!/bin/bash
# Start Godot editor with OpenGL3 renderer
godot4 --rendering-driver opengl3 --path "$(dirname "$0")" --editor