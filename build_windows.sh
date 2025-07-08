#!/bin/bash

echo "Building Windows executable from Linux..."
echo "This script requires Godot export templates to be installed."
echo ""

# Check if export templates exist (snap version)
TEMPLATE_DIR="$HOME/snap/godot4/9/.local/share/godot/export_templates/4.3.stable"
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "Export templates not found. Please install them:"
    echo "1. Open Godot Editor"
    echo "2. Go to Editor > Manage Export Templates"
    echo "3. Download and install the 4.3 templates"
    echo "4. Or manually download from:"
    echo "   https://downloads.tuxfamily.org/godotengine/4.3/Godot_v4.3-stable_export_templates.tpz"
    echo "5. Extract to: $TEMPLATE_DIR"
    echo ""
    echo "Alternatively, you can export from the Godot Editor:"
    echo "1. Open the project in Godot"
    echo "2. Go to Project > Export"
    echo "3. Add the Windows Desktop preset"
    echo "4. Export the project"
    exit 1
fi

echo "Export templates found. Building Windows executable..."

# Define output paths
SHARED_FOLDER="/media/sf_projects/feline_vibes"
LOCAL_BUILDS="builds"
OUTPUT_EXE="$SHARED_FOLDER/feline_vibes_windows.exe"

# Create directories
mkdir -p "$SHARED_FOLDER"
mkdir -p "$LOCAL_BUILDS"

# Export Windows build to local directory first
LOCAL_EXE="$LOCAL_BUILDS/feline_vibes_windows.exe"
godot4 --headless --export-release "Windows Desktop" "$LOCAL_EXE"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Windows build successful!"
    echo "📁 Local output: $LOCAL_EXE"
    echo "📊 File size: $(du -h "$LOCAL_EXE" | cut -f1)"
    
    # Copy to shared folder
    echo "📁 Copying to shared folder: $SHARED_FOLDER"
    cp "$LOCAL_EXE" "$OUTPUT_EXE"
    if [ -f "$LOCAL_BUILDS/feline_vibes_windows.pck" ]; then
        cp "$LOCAL_BUILDS/feline_vibes_windows.pck" "$SHARED_FOLDER/"
    fi
    
    echo ""
    echo "🎯 Ready for Windows distribution:"
    echo "   - Main output: $SHARED_FOLDER"
    echo "   - Local backup: $LOCAL_BUILDS"
    echo "   - Copy both .exe and .pck files to Windows machine"
else
    echo "❌ Build failed. Check the export preset configuration."
    echo "You may need to use the Godot Editor to set up exports properly."
fi