# [MiniTools](https://github.com/Perrolito/MiniTools.py/)

A small but modern looking GUI application for Linux system information and maintenance, built with PyQt6.

## Features

- **System Information**: Display CPU, memory, kernel, swap, and disk information
- **System Maintenance**: Check for system updates and Flatpak updates
- **Disk Operations**: Change partition UUID
- **Extensions**: Support for custom shell (`.sh`) and Python (`.py`) scripts
- **Modern UI**: Clean, responsive interface with dark/light theme support
- **Customizable**: Adjustable font size for the output log

![PREVIEW](https://github.com/Perrolito/MiniTools.py/blob/main/preview.png)

## Requirements

- Python 3.6+
- PyQt6

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd MiniTools
```

2. Install dependencies:
```bash
pip install PyQt6
```

3. Run the application:
```bash
python3 MiniTools.py
```

## Usage

Click any button in the interface to use the corresponding tool. The output will be displayed in the log panel.

### Adding Extensions

Place your custom scripts (`.sh` or `.py`) in `~/.config/hotodogo/minitools/extensions/`. They will automatically appear in the Extensions section.

## Building Packages

### Linux Packages

#### DEB Package (Debian/Ubuntu)

```bash
./build.sh -f deb
# Or interactive mode: ./build.sh and select option 1
```

**Requirements:** `dpkg-deb`

#### RPM Package (Fedora/RHEL)

```bash
./build.sh -f rpm
# Or interactive mode: ./build.sh and select option 2
```

**Requirements:** `rpmbuild`

#### AppImage

**System Python** (requires Python3 and PyQt6 on target system)

```bash
# Download appimagetool first
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -P build/
chmod +x build/appimagetool-x86_64.AppImage

# Build
./build.sh -f appimage
# Or: ./build.sh and select option 3
```

**Self-contained** (includes Python3 and PyQt6, works on any Linux system)

```bash
# Install PyInstaller
pip install pyinstaller

# Build
./build.sh -f self-contained
# Or: ./build.sh and select option 4
```

This method uses [PyInstaller](https://pyinstaller.org/) to bundle the application with Python and all dependencies into a single executable.

### macOS Packages

**Note:** macOS packages can only be built on macOS. For cross-platform builds, use GitHub Actions with macOS runner.

#### macOS App Bundle (.app)

```bash
# Install dependencies
pip install pyinstaller
brew install imagemagick  # or: brew install --cask inkscape

# Build .app bundle
./build.sh -f macos
# Or interactive mode: ./build.sh and select option 5
```

The build script will automatically convert `minitools.svg` to `minitools.icns` using ImageMagick or Inkscape.

#### macOS DMG Installer

```bash
# Install dependencies
pip install pyinstaller dmgbuild
brew install imagemagick  # or: brew install --cask inkscape

# Build .app + .dmg
./build.sh -f dmg
# Or interactive mode: ./build.sh and select option 6
```

### Windows Packages

**Note:** Windows packages can only be built on Windows.

#### Windows EXE

1. **Install Python**

   Download and install Python from https://www.python.org/downloads/

   **Important:** During installation, check "Add Python to PATH"

2. **Install dependencies** (optional - build.bat will install them automatically if missing)

   ```batch
   pip install pyinstaller PyQt6 Pillow psutil wmi
   ```

3. **Build EXE**

   ```batch
   build.bat
   ```

   Or double-click `build.bat` in File Explorer

The build script will:
- Check if Python is installed
- Automatically install PyInstaller if missing
- Automatically install PyQt6 if missing
- Automatically install psutil and wmi for Windows system information
- Automatically install Pillow for icon conversion
- Build a standalone Windows EXE that includes Python and all dependencies

**About the EXE:**
- The EXE is completely standalone - it includes Python interpreter, PyQt6, psutil, wmi, Pillow, and all other dependencies
- No additional dependencies required to run the EXE
- Can be run on any Windows system (64-bit or ARM64) without installing Python or any packages
- Simply double-click the EXE to run

The executable will be created as: `build/minitools-1.0.2-amd64-self-contained.exe` (on 64-bit systems) or `build/minitools-1.0.2-aarch64-self-contained.exe` (on ARM systems).

**Note:** On Windows, some Linux-specific features (like package manager updates, Flatpak updates) are not available. System information (CPU, memory, disk, etc.) is fully supported.

### Command Line Options

```bash
# Show help
./build.sh -h

# Build specific format
./build.sh -f deb              # DEB package
./build.sh -f rpm              # RPM package
./build.sh -f appimage         # AppImage (system Python)
./build.sh -f self-contained    # Self-contained AppImage
./build.sh -f macos            # macOS .app (macOS only)
./build.sh -f dmg              # macOS .dmg (macOS only)
./build.sh -f all              # All formats for current platform

# Non-interactive mode
./build.sh -f deb -n
```

### Download Build Tools

```bash
./download-build-tools.sh
```

This downloads appimagetool to the `build/` directory for Linux builds.

### Package Naming

All packages use the unified naming format: `{name}-{version}-{arch}.{ext}`

- **DEB**: `minitools-1.0.2-amd64.deb`
- **RPM**: `minitools-1.0.2-amd64.rpm`
- **AppImage**: `minitools-1.0.2-amd64.AppImage`
- **Self-contained AppImage**: `minitools-1.0.2-amd64-self-contained.AppImage`
- **macOS .app**: `minitools-1.0.2-amd64.app`
- **macOS .dmg**: `minitools-1.0.2-amd64.dmg`
- **Windows EXE**: `minitools-1.0.2-amd64-self-contained.exe`

## License

GNU General Public License v3.0 (GPL-3.0)
