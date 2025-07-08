# Building Windows Executables

## Method 1: Using Godot Editor (Recommended)

1. **Open the project in Godot Editor:**
   ```bash
   ./editor.sh
   ```

2. **Install Export Templates:**
   - Go to `Editor` → `Manage Export Templates`
   - Click `Download and Install` for version 4.3
   - Wait for download to complete

3. **Configure Windows Export:**
   - Go to `Project` → `Export`
   - Click `Add...` → `Windows Desktop`
   - Configure settings if needed (defaults are fine)
   - Set export path: `builds/feline_vibes_windows.exe`

4. **Export the Game:**
   - Click `Export Project`
   - Choose location and click `Save`

## Method 2: Command Line (After Templates Installed)

1. **Run the build script:**
   ```bash
   ./build_windows.sh
   ```

2. **Or manually:**
   ```bash
   godot4 --headless --export-release "Windows Desktop" "builds/feline_vibes_windows.exe"
   ```

## Cross-Platform Build Support

✅ **Windows** - Full support from Linux
✅ **Linux** - Native builds
✅ **macOS** - Requires macOS machine for signing
✅ **Web** - WebAssembly builds supported
✅ **Android** - APK builds with additional setup

## Distribution

The built Windows executable is **self-contained** and includes:
- Game engine runtime
- All scripts and scenes
- Textures and assets
- No external dependencies required

## File Structure

```
builds/
├── feline_vibes_windows.exe    # Windows executable (~50-100MB)
├── feline_vibes_linux.x86_64   # Linux executable (if built)
└── feline_vibes_web/           # Web build directory (if built)
```

## Tips

- **Debug builds** are larger but include error reporting
- **Release builds** are optimized and smaller
- **Export templates** only need to be downloaded once per Godot version
- **Cross-compilation** works seamlessly for Windows from Linux