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

### DEB Package

```bash
./build.sh
# Select option 1
```

### RPM Package

```bash
./build.sh
# Select option 2
```

### AppImage

**Note**: Requires downloading appimagetool first:

```bash
# Download appimagetool to build directory
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -P build/
chmod +x build/appimagetool-x86_64.AppImage
```

#### System Python

Requires Python3 and PyQt6 installed on the target system.

```bash
# Build
./build.sh
# Select option 3
```

#### Self-contained

Includes Python3 and PyQt6, works on any Linux system without dependencies.

**Requirements:**
- PyInstaller: `pip install pyinstaller`

```bash
# Build
./build.sh
# Select option 4
```

This method uses [PyInstaller](https://pyinstaller.org/) to bundle the application with Python and all dependencies into a single executable.

## License

GNU General Public License v3.0 (GPL-3.0)
