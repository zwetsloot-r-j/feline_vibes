#!/bin/bash

# Script to move OBJ, MTL, and PNG files to assets/models folder
# Usage: ./move_assets.sh filename_without_extension

if [ $# -eq 0 ]; then
    echo "Usage: $0 <filename_without_extension>"
    echo "Example: $0 cat001-5-head"
    echo ""
    echo "This will move:"
    echo "  /media/sf_projects/feline_vibes/obj/cat001-5-head.obj"
    echo "  /media/sf_projects/feline_vibes/obj/cat001-5-head.mtl"
    echo "  /media/sf_projects/feline_vibes/obj/cat001-5-head.png"
    echo "To:"
    echo "  ./assets/models/"
    exit 1
fi

FILENAME="$1"
SOURCE_DIR="/media/sf_projects/feline_vibes/obj"
TARGET_DIR="./assets/models"

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

echo "Moving files for: $FILENAME"
echo "From: $SOURCE_DIR"
echo "To: $TARGET_DIR"
echo ""

# Function to move file if it exists
move_file() {
    local ext="$1"
    local source_file="$SOURCE_DIR/$FILENAME.$ext"
    local target_file="$TARGET_DIR/$FILENAME.$ext"
    
    if [ -f "$source_file" ]; then
        echo "Moving $FILENAME.$ext..."
        mv "$source_file" "$target_file"
        if [ $? -eq 0 ]; then
            echo "  ✓ Successfully moved $FILENAME.$ext"
        else
            echo "  ✗ Failed to move $FILENAME.$ext"
        fi
    else
        echo "  - $FILENAME.$ext not found in source directory"
    fi
}

# Move the files
move_file "obj"
move_file "mtl" 
move_file "png"

echo ""
echo "Asset movement complete!"
echo ""
echo "Files now in assets/models/:"
ls -la "$TARGET_DIR/$FILENAME".*  2>/dev/null || echo "No files found with name $FILENAME in target directory"