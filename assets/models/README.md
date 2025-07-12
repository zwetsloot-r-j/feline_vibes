# Assets/Models Folder

## Usage

Place your model files here for automatic discovery:

- **OBJ files**: 3D models 
- **MTL files**: Material definitions
- **PNG/JPG files**: Textures

## How it works

When you load an OBJ file, the system automatically looks in this folder for:

1. **MTL file** with the same name as the OBJ
2. **Any MTL file** referenced in the OBJ
3. **PNG/JPG textures** referenced in the MTL file
4. **Any PNG/JPG files** that might be textures

## Example

If you have a model called `cat.obj`, place these files here:
- `cat.obj` (can be loaded from anywhere)
- `cat.mtl` 
- `cat.png` or `cat_texture.png` or similar

The system will automatically find and use the MTL and PNG files for proper colors and textures.