#!/bin/bash
# MiniTools Build Script
# Build deb, rpm, and AppImage packages directly

set -e

# Get script directory (absolute path)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# PROJECT_ROOT is the directory containing build.sh and MiniTools.py
# If build.sh is in the project root (e.g., /path/to/project/build.sh),
# then SCRIPT_DIR == PROJECT_ROOT
# If build.sh is in a subdirectory (e.g., /path/to/project/build/build.sh),
# then PROJECT_ROOT is SCRIPT_DIR's parent
PROJECT_ROOT="$SCRIPT_DIR"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Application metadata
APP_NAME="MiniTools"
APP_PKG_NAME="minitools"
APP_PYTHON_SCRIPT="MiniTools.py"
APP_ICON="minitools.png"

# Architecture detection
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        ARCH_SUFFIX="amd64"
        ;;
    aarch64)
        ARCH_SUFFIX="aarch64"
        ;;
    arm64)
        ARCH_SUFFIX="aarch64"
        ;;
    *)
        ARCH_SUFFIX="$ARCH"
        ;;
esac

# Path definitions
APP_SCRIPT_PATH="$PROJECT_ROOT/$APP_PYTHON_SCRIPT"
APP_ICON_PATH="$PROJECT_ROOT/$APP_ICON"

# Package naming format: {pkg}-{version}-{arch}.{ext}
# AppImage format: {name}-{version}-{arch}.{type}.{ext}

echo -e "${CYAN}==========================================${NC}"
echo -e "${GREEN}  MiniTools Build Script${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: Don't run this script as root${NC}"
    exit 1
fi

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
else
    DISTRO="unknown"
fi

echo -e "${BLUE}Detected distribution: $DISTRO${NC}"
echo ""

# Get version from script or use default
VERSION="1.0.0"
if [ -f "$APP_SCRIPT_PATH" ]; then
    VERSION=$(grep "__version__" "$APP_SCRIPT_PATH" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "1.0.0")
    echo -e "${BLUE}Detected version from $APP_PYTHON_SCRIPT: $VERSION${NC}"
else
    echo -e "${YELLOW}$APP_PYTHON_SCRIPT not found, using default version: $VERSION${NC}"
fi

echo -e "${GREEN}Building MiniTools version: $VERSION${NC}"
echo ""

# Create build directory
BUILD_DIR="build"
mkdir -p "$BUILD_DIR"
# Build directory (relative to script location)
BUILD_DIR="$SCRIPT_DIR/build"
mkdir -p "$BUILD_DIR"

# Note: Previous builds are not automatically cleaned to allow multiple formats
# To clean, run: rm -rf build/*.deb build/*.rpm build/*.AppImage build/minitools_* build/MiniTools.AppDir

# ============================================================================
# Interactive Menu for Build Format Selection
# ============================================================================
echo -e "${CYAN}==========================================${NC}"
echo -e "${GREEN}  Select Build Format${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""
echo "1) DEB Package (Debian/Ubuntu)"
echo "2) RPM Package (Fedora/RHEL)"
echo "3) AppImage (Universal, requires system Python3)"
echo "4) AppImage (Self-contained, includes Python3)"
echo "5) All formats"
echo "0) Exit"
echo ""
read -p "Enter your choice [0-5]: " choice

BUILD_DEB="false"
BUILD_RPM="false"
BUILD_APPIMAGE="false"
BUILD_APPIMAGE_BUNDLE="false"

case $choice in
    1)
        BUILD_DEB="true"
        ;;
    2)
        BUILD_RPM="true"
        ;;
    3)
        BUILD_APPIMAGE="true"
        ;;
    4)
        BUILD_APPIMAGE_BUNDLE="true"
        ;;
    5)
        BUILD_DEB="true"
        BUILD_RPM="true"
        BUILD_APPIMAGE="true"
        BUILD_APPIMAGE_BUNDLE="true"
        ;;
    0)
        echo -e "${YELLOW}Build cancelled${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}Building formats: ${NC}"
[ "$BUILD_DEB" = "true" ] && echo -e "  ${GREEN}✓ DEB${NC}"
[ "$BUILD_RPM" = "true" ] && echo -e "  ${GREEN}✓ RPM${NC}"
[ "$BUILD_APPIMAGE" = "true" ] && echo -e "  ${GREEN}✓ AppImage (System Python)${NC}"
[ "$BUILD_APPIMAGE_BUNDLE" = "true" ] && echo -e "  ${GREEN}✓ AppImage (Self-contained)${NC}"
echo ""

# ============================================================================
# Build DEB Package (Debian/Ubuntu based)
# ============================================================================
if [ "$BUILD_DEB" = "true" ]; then
    echo -e "${BLUE}Checking DEB build capability...${NC}"

CAN_BUILD_DEB="false"
if command -v dpkg-deb >/dev/null 2>&1; then
    CAN_BUILD_DEB="true"
    echo -e "${GREEN}✓ dpkg-deb found${NC}"
else
    echo -e "${RED}✗ dpkg-deb not found - skipping DEB build${NC}"
    echo -e "  Install with: sudo apt install dpkg-dev${NC}"
fi

if [ "$CAN_BUILD_DEB" = "true" ]; then
    echo -e "${BLUE}Building DEB package...${NC}"

    # Unified package naming: minitools-1.0.2-amd64.deb
    DEB_OUTPUT="${BUILD_DIR}/${APP_PKG_NAME}-${VERSION}-${ARCH_SUFFIX}.deb"
    DEB_DIR="${BUILD_DIR}/${APP_PKG_NAME}_${VERSION}_${ARCH_SUFFIX}"
    DEB_INSTALL_DIR="/opt/$APP_PKG_NAME"
    DEB_BIN_DIR="/usr/bin/$APP_PKG_NAME"
    DEB_DESKTOP_FILE="$APP_PKG_NAME.desktop"
    DEB_ICON_FILE="$APP_PKG_NAME.png"

    # Clean up previous build artifacts
    echo -e "${YELLOW}Cleaning up previous DEB build artifacts...${NC}"
    rm -rf "$DEB_DIR"
    rm -f "$DEB_OUTPUT"

    mkdir -p "$DEB_DIR/DEBIAN"
    mkdir -p "$DEB_DIR/$DEB_INSTALL_DIR"
    mkdir -p "$DEB_DIR/usr/share/applications"
    mkdir -p "$DEB_DIR/usr/share/pixmaps"
    mkdir -p "$DEB_DIR/usr/bin"

    # Copy application files
    cp "$APP_SCRIPT_PATH" "$DEB_DIR/$DEB_INSTALL_DIR/$APP_PYTHON_SCRIPT"
    chmod +x "$DEB_DIR/$DEB_INSTALL_DIR/$APP_PYTHON_SCRIPT"

    # Copy icon if available
    if [ -f "$APP_ICON_PATH" ]; then
        cp "$APP_ICON_PATH" "$DEB_DIR/usr/share/pixmaps/$DEB_ICON_FILE"
        echo -e "${GREEN}✓ Icon copied${NC}"
    else
        echo -e "${YELLOW}⚠ Icon not found ($APP_ICON), skipping...${NC}"
    fi

    # Create launcher script
    cat > "$DEB_DIR/usr/bin/$APP_PKG_NAME" << EOF
#!/bin/bash
cd $DEB_INSTALL_DIR
python3 $APP_PYTHON_SCRIPT "\$@"
EOF
    chmod +x "$DEB_DIR/usr/bin/$APP_PKG_NAME"

    # Create desktop entry
    cat > "$DEB_DIR/usr/share/applications/$DEB_DESKTOP_FILE" << EOF
[Desktop Entry]
Name=$APP_NAME
Comment=System Information and Maintenance Tools
Exec=$DEB_BIN_DIR
Icon=$APP_PKG_NAME
Terminal=false
Type=Application
Categories=System;Utility;
Keywords=system;monitor;maintenance;
EOF

    # Create control file
    cat > "$DEB_DIR/DEBIAN/control" << EOF
Package: $APP_PKG_NAME
Version: ${VERSION}
Architecture: ${ARCH_SUFFIX}
Maintainer: MiniTools Team
Installed-Size: 1024
Section: utils
Priority: optional
Homepage: https://github.com/Perrolito/MiniTools.py/
Description: System Information and Maintenance Tools
 MiniTools is a modern GUI application for system information
 display and maintenance. It provides tools for viewing CPU,
 memory, disk information, managing software updates, and more.
Depends: python3, python3-pyqt6
EOF
    
    # Build DEB
    dpkg-deb --build "$DEB_DIR" "$DEB_OUTPUT" 2>&1
    if [ -f "$DEB_OUTPUT" ]; then
        echo -e "${GREEN}✓ DEB package created: $DEB_OUTPUT${NC}"
    else
        echo -e "${RED}✗ DEB package build failed${NC}"
    fi
fi
fi

# ============================================================================
# Build RPM Package (RHEL/Fedora based)
# ============================================================================
if [ "$BUILD_RPM" = "true" ]; then
    echo ""
    echo -e "${BLUE}Checking RPM build capability...${NC}"

    CAN_BUILD_RPM="false"
    if command -v rpmbuild >/dev/null 2>&1; then
        CAN_BUILD_RPM="true"
        echo -e "${GREEN}✓ rpmbuild found${NC}"
    else
        echo -e "${RED}✗ rpmbuild not found - skipping RPM build${NC}"
        echo -e "  Install with: sudo dnf install rpm-build${NC}"
    fi

    if [ "$CAN_BUILD_RPM" = "true" ]; then
    echo -e "${BLUE}Building RPM package...${NC}"

    # Unified package naming: minitools-1.0.2-amd64.rpm
    RPM_OUTPUT="${BUILD_DIR}/${APP_PKG_NAME}-${VERSION}-${ARCH_SUFFIX}.rpm"
    # Create rpmbuild directory structure
    mkdir -p "${BUILD_DIR}/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}"
    RPM_RPMS_DIR="${BUILD_DIR}/rpmbuild/RPMS/x86_64"

    # Clean up previous build artifacts
    echo -e "${YELLOW}Cleaning up previous RPM build artifacts...${NC}"
    rm -rf rpmbuild
    rm -f "$RPM_OUTPUT"

    # Create rpmbuild directory structure
    mkdir -p rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

    # Create spec file
    cat > "${BUILD_DIR}/rpmbuild/SPECS/${APP_PKG_NAME}.spec" << EOF
Name:           $APP_PKG_NAME
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        System Information and Maintenance Tools
License:        MIT
URL:            https://github.com/Perrolito/MiniTools.py/
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  python3-devel, python3-pyqt6-devel
Requires:       python3, python3-pyqt6

%description
MiniTools is a modern GUI application for system information
display and maintenance. It provides tools for viewing CPU,
memory, disk information, managing software updates, and more.

%prep
%setup -q

%build
# No build needed for Python script

%install
mkdir -p %{buildroot}/opt/$APP_PKG_NAME
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/applications

install -m 755 $APP_PYTHON_SCRIPT %{buildroot}/opt/$APP_PKG_NAME/

cat > %{buildroot}/usr/bin/$APP_PKG_NAME << SCRIPT
#!/bin/bash
cd /opt/$APP_PKG_NAME
python3 $APP_PYTHON_SCRIPT "\$@"
SCRIPT
chmod 755 %{buildroot}/usr/bin/$APP_PKG_NAME

cat > %{buildroot}/usr/share/applications/$APP_PKG_NAME.desktop << 'DESKTOP'
[Desktop Entry]
Name=$APP_NAME
Comment=System Information and Maintenance Tools
Exec=/usr/bin/$APP_PKG_NAME
Icon=$APP_PKG_NAME
Terminal=false
Type=Application
Categories=System;Utility;
DESKTOP

%files
/opt/$APP_PKG_NAME/$APP_PYTHON_SCRIPT
/usr/bin/$APP_PKG_NAME
/usr/share/applications/$APP_PKG_NAME.desktop

%changelog
* $(date +'%a %b %d %Y') MiniTools Team <team@minitools.com> - ${VERSION}-1
- Initial package
EOF

    # Create source tarball
    mkdir -p "${BUILD_DIR}/${APP_PKG_NAME}-${VERSION}"
    cp "$APP_SCRIPT_PATH" "${BUILD_DIR}/${APP_PKG_NAME}-${VERSION}/"
    tar -czf "${BUILD_DIR}/rpmbuild/SOURCES/${APP_PKG_NAME}-${VERSION}.tar.gz" -C "${BUILD_DIR}" "${APP_PKG_NAME}-${VERSION}"

    # Build RPM
    rpmbuild -ba "${BUILD_DIR}/rpmbuild/SPECS/${APP_PKG_NAME}.spec" --define "_topdir $(pwd)/${BUILD_DIR}/rpmbuild" 2>&1

    # Find and copy the built RPM
    RPM_FILE="${RPM_RPMS_DIR}/${APP_PKG_NAME}-${VERSION}-1.${ARCH_SUFFIX}.rpm"
    if [ -f "$RPM_FILE" ]; then
        cp "$RPM_FILE" "$RPM_OUTPUT"
        echo -e "${GREEN}✓ RPM package created: $RPM_OUTPUT${NC}"
    else
        echo -e "${RED}✗ RPM package build failed${NC}"
    fi
    fi
fi

# ============================================================================
# Build AppImage
# ============================================================================
if [ "$BUILD_APPIMAGE" = "true" ]; then
    echo ""
    echo -e "${BLUE}Checking AppImage build capability...${NC}"

    CAN_BUILD_APPIMAGE="false"
    if command -v wget >/dev/null 2>&1; then
        CAN_BUILD_APPIMAGE="true"
        echo -e "${GREEN}✓ wget found${NC}"
    else
        echo -e "${RED}✗ wget not found - skipping AppImage build${NC}"
        echo -e "  Install with: sudo apt install wget  # or dnf install wget${NC}"
    fi

    if [ "$CAN_BUILD_APPIMAGE" = "true" ]; then
    echo -e "${BLUE}Building AppImage package...${NC}"
    echo -e "${YELLOW}Note: This AppImage requires Python3 to be installed on the target system.${NC}"
    echo -e "${YELLOW}For a self-contained AppImage with Python, use tools like 'linuxdeploy' or 'pyapp'.${NC}"
    echo ""

    # Unified package naming: MiniTools-1.0.2-amd64.AppImage
    APPDIR="${BUILD_DIR}/${APP_NAME}.AppDir"
    APPDESKTOP_FILE="${APP_PKG_NAME}.desktop"
    APPIMAGE_OUTPUT="${BUILD_DIR}/${APP_NAME}-${VERSION}-${ARCH_SUFFIX}.AppImage"
    # Keep original tool names (x86_64 is the actual tool name, not our package naming)
    APPIMAGETOOL_NAME="appimagetool-x86_64.AppImage"
    APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/$APPIMAGETOOL_NAME"

    # Check for appimagetool in build directory or current directory
    if [ -f "$BUILD_DIR/$APPIMAGETOOL_NAME" ]; then
        APPIMAGETOOL="$BUILD_DIR/$APPIMAGETOOL_NAME"
    elif [ -f "$APPIMAGETOOL_NAME" ]; then
        APPIMAGETOOL="./$APPIMAGETOOL_NAME"
    else
        APPIMAGETOOL="$APPIMAGETOOL_NAME"
    fi

    # Clean up previous build artifacts
    echo -e "${YELLOW}Cleaning up previous AppImage build artifacts...${NC}"
    rm -rf "$APPDIR"
    rm -f "$APPIMAGE_OUTPUT"

    mkdir -p "$APPDIR/usr/bin"
    mkdir -p "$APPDIR/usr/share/applications"
    mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"

    # Copy application
    cp "$APP_SCRIPT_PATH" "$APPDIR/usr/bin/$APP_PKG_NAME"
    chmod +x "$APPDIR/usr/bin/$APP_PKG_NAME"

    # Copy icon if available
    if [ -f "$APP_ICON_PATH" ]; then
        # Copy to AppDir root (required by appimagetool)
        cp "$APP_ICON_PATH" "$APPDIR/$APP_PKG_NAME.png"
        # Also copy to system icons directory
        cp "$APP_ICON_PATH" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$APP_PKG_NAME.png"
        echo -e "${GREEN}✓ Icon copied for AppImage${NC}"
    else
        echo -e "${YELLOW}⚠ Icon not found ($APP_ICON), skipping...${NC}"
    fi

    # Create AppRun
    cat > "$APPDIR/AppRun" << EOF
#!/bin/bash
SELF=\$(readlink -f "\$0")
HERE=\${SELF%/*}

# Use system Python3, not AppImage internal path
export PATH="\${HERE}/usr/bin:\${PATH}"
export PYTHONPATH="\${HERE}/usr/lib/python3/site-packages:\${PYTHONPATH}"

cd "\${HERE}"
exec python3 "\${HERE}/usr/bin/$APP_PKG_NAME" "\$@"
EOF
    chmod +x "$APPDIR/AppRun"

    # Create desktop file
    cat > "$APPDIR/$APPDESKTOP_FILE" << EOF
[Desktop Entry]
Name=$APP_NAME
Comment=System Information and Maintenance Tools
Exec=AppRun
Icon=$APP_PKG_NAME
Terminal=false
Type=Application
Categories=System;Utility;
EOF

    # Copy desktop file to AppImage location
    cp "$APPDIR/$APPDESKTOP_FILE" "$APPDIR/usr/share/applications/"
    APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/$APPIMAGETOOL"
    
    echo ""
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${CYAN}  appimagetool Check${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${BLUE}Working directory: $(pwd)${NC}"
    echo -e "${BLUE}Looking for: $APPIMAGETOOL${NC}"
    
    # List all AppImage files in current directory
    if ls *.AppImage 2>/dev/null; then
        echo -e "${GREEN}Found AppImage files:${NC}"
        ls -lh *.AppImage
    else
        echo -e "${YELLOW}No AppImage files found in current directory${NC}"
    fi
    echo -e "${CYAN}==========================================${NC}"
    echo ""
    
    NEED_DOWNLOAD=true
    
    if [ -f "$APPIMAGETOOL" ]; then
        echo -e "${GREEN}✓ appimagetool already exists${NC}"
        echo -e "${YELLOW}File: $(pwd)/$APPIMAGETOOL${NC}"
        echo -e "${YELLOW}Size: $(du -h "$APPIMAGETOOL" | cut -f1)${NC}"
        echo ""
        echo -e "${CYAN}Press Enter to use existing file, or type 'y' to re-download:${NC}"
        read -p "Your choice (default: use existing): " redownload
        echo ""
        if [[ "$redownload" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Re-downloading appimagetool...${NC}"
            rm -f "$APPIMAGETOOL"
            NEED_DOWNLOAD=true
        else
            echo -e "${GREEN}Using existing file${NC}"
            NEED_DOWNLOAD=false
        fi
    fi
    
    if [ "$NEED_DOWNLOAD" = true ]; then
        echo -e "${YELLOW}Downloading appimagetool...${NC}"
        echo -e "${BLUE}  Download URL: $APPIMAGETOOL_URL${NC}"
        echo -e "${BLUE}  Save location: $(pwd)/$APPIMAGETOOL${NC}"
        echo -e "${CYAN}  If download is too slow, you can download manually and place it here.${NC}"
        wget --show-progress -O "$APPIMAGETOOL" "$APPIMAGETOOL_URL"
        if [ -f "$APPIMAGETOOL" ] && [ -s "$APPIMAGETOOL" ]; then
            chmod +x "$APPIMAGETOOL"
            echo -e "${GREEN}✓ Download completed${NC}"
        else
            echo -e "${RED}✗ Download failed${NC}"
        fi
    fi
    
    # Build AppImage
    if [ -f "$APPIMAGETOOL" ]; then
        ARCH=x86_64 "$APPIMAGETOOL" "$APPDIR" "$APPIMAGE_OUTPUT" 2>&1
        if [ -f "$APPIMAGE_OUTPUT" ]; then
            chmod +x "$APPIMAGE_OUTPUT"
            echo -e "${GREEN}✓ AppImage package created: $APPIMAGE_OUTPUT${NC}"
        else
            echo -e "${RED}✗ AppImage package build failed${NC}"
        fi
    else
        echo -e "${RED}✗ appimagetool download failed${NC}"
    fi
    fi
fi

# ============================================================================
# Build Self-Contained AppImage (includes Python3 and PyQt6)
# ============================================================================
if [ "$BUILD_APPIMAGE_BUNDLE" = "true" ]; then
    echo ""
    echo -e "${BLUE}Building Self-Contained AppImage package...${NC}"
    echo -e "${YELLOW}Note: This will use PyInstaller to bundle the application${NC}"
    echo -e "${YELLOW}      This will create a much larger AppImage but works on any system${NC}"
    echo ""

    # Check for appimagetool
    APPIMAGETOOL="appimagetool-x86_64.AppImage"
    if [ -f "$BUILD_DIR/$APPIMAGETOOL" ]; then
        APPIMAGETOOL="$BUILD_DIR/$APPIMAGETOOL"
    elif [ -f "$APPIMAGETOOL" ]; then
        APPIMAGETOOL="./$APPIMAGETOOL"
    else
        echo -e "${RED}✗ appimagetool not found${NC}"
        echo -e "${YELLOW}Download appimagetool to build directory:${NC}"
        echo -e "  wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -P build/"
        echo -e "  chmod +x build/appimagetool-x86_64.AppImage"
        echo ""
        echo -e "${YELLOW}Or run: ./download-build-tools.sh${NC}"
        echo ""
        BUILD_APPIMAGE_BUNDLE="false"
    fi

    # Check for PyInstaller
    if ! command -v pyinstaller &> /dev/null; then
        echo -e "${RED}✗ PyInstaller not found${NC}"
        echo -e "${YELLOW}Install PyInstaller:${NC}"
        echo -e "  pip install pyinstaller${NC}"
        echo ""
        BUILD_APPIMAGE_BUNDLE="false"
    fi

    if [ "$BUILD_APPIMAGE_BUNDLE" = "true" ]; then
        # Create AppDir for self-contained build
        # Unified package naming: MiniTools-1.0.2-amd64-self-contained.AppImage
        SELF_CONTAINED_APPDIR="${BUILD_DIR}/${APP_NAME}.SelfContained.AppDir"
        SELF_CONTAINED_OUTPUT="${BUILD_DIR}/${APP_NAME}-${VERSION}-${ARCH_SUFFIX}-self-contained.AppImage"
        PYINSTALLER_DIR="${BUILD_DIR}/pyinstaller_build"

        # Clean up previous build artifacts
        echo -e "${YELLOW}Cleaning up previous Self-Contained AppImage build artifacts...${NC}"
        rm -rf "$SELF_CONTAINED_APPDIR"
        rm -f "$SELF_CONTAINED_OUTPUT"
        rm -rf "$PYINSTALLER_DIR"

        # Create AppDir structure
        mkdir -p "$SELF_CONTAINED_APPDIR/usr/bin"
        mkdir -p "$SELF_CONTAINED_APPDIR/usr/share/applications"
        mkdir -p "$SELF_CONTAINED_APPDIR/usr/share/icons/hicolor/256x256/apps"

        # Build with PyInstaller
        echo -e "${BLUE}Building with PyInstaller...${NC}"
        pyinstaller --onefile \
            --name "$APP_PKG_NAME" \
            --distpath "$SELF_CONTAINED_APPDIR/usr/bin" \
            --icon="$APP_ICON_PATH" \
            --windowed \
            --hidden-import=PyQt6 \
            --hidden-import=PyQt6.QtCore \
            --hidden-import=PyQt6.QtGui \
            --hidden-import=PyQt6.QtWidgets \
            "$APP_SCRIPT_PATH"

        if [ ! -f "$SELF_CONTAINED_APPDIR/usr/bin/$APP_PKG_NAME" ]; then
            echo -e "${RED}✗ PyInstaller build failed${NC}"
            BUILD_APPIMAGE_BUNDLE="false"
        fi
    fi

    if [ "$BUILD_APPIMAGE_BUNDLE" = "true" ]; then
        # Copy icon
        if [ -f "$APP_ICON_PATH" ]; then
            cp "$APP_ICON_PATH" "$SELF_CONTAINED_APPDIR/$APP_PKG_NAME.png"
            cp "$APP_ICON_PATH" "$SELF_CONTAINED_APPDIR/usr/share/icons/hicolor/256x256/apps/$APP_PKG_NAME.png"
        fi

        # Create AppRun
        cat > "$SELF_CONTAINED_APPDIR/AppRun" << EOF
#!/bin/bash
SELF=\$(readlink -f "\$0")
HERE=\${SELF%/*}

cd "\${HERE}"
exec "\${HERE}/usr/bin/$APP_PKG_NAME" "\$@"
EOF
        chmod +x "$SELF_CONTAINED_APPDIR/AppRun"

        # Create desktop file
        cat > "$SELF_CONTAINED_APPDIR/$APP_PKG_NAME.desktop" << EOF
[Desktop Entry]
Name=$APP_NAME
Comment=System Information and Maintenance Tools
Exec=AppRun
Icon=$APP_PKG_NAME
Terminal=false
Type=Application
Categories=System;Utility;
EOF

        # Build AppImage using appimagetool
        echo -e "${BLUE}Building AppImage with appimagetool...${NC}"
        ARCH=x86_64 "$APPIMAGETOOL" "$SELF_CONTAINED_APPDIR" "$SELF_CONTAINED_OUTPUT" 2>&1

        if [ -f "$SELF_CONTAINED_OUTPUT" ]; then
            chmod +x "$SELF_CONTAINED_OUTPUT"
            echo -e "${GREEN}✓ Self-contained AppImage created: $SELF_CONTAINED_OUTPUT${NC}"
        else
            echo -e "${RED}✗ Self-contained AppImage build failed${NC}"
        fi

        # Clean up PyInstaller build directory
        rm -rf "$PYINSTALLER_DIR"
    fi
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo -e "${CYAN}==========================================${NC}"
echo -e "${GREEN}  Build Summary${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""
echo -e "${BLUE}Packages created in: $BUILD_DIR${NC}"
echo ""

# List created packages
DEB_COUNT=$(ls "${BUILD_DIR}"/${APP_PKG_NAME}-*.deb 2>/dev/null | wc -l)
RPM_COUNT=$(ls "${BUILD_DIR}"/${APP_PKG_NAME}-*.rpm 2>/dev/null | wc -l)
APPIMAGE_COUNT=$(ls "${BUILD_DIR}"/${APP_NAME}-*.AppImage 2>/dev/null | wc -l)

if [ "$DEB_COUNT" -gt 0 ]; then
    echo -e "${GREEN}DEB packages:${NC}"
    ls -lh "${BUILD_DIR}"/${APP_PKG_NAME}-*.deb 2>/dev/null
fi

if [ "$RPM_COUNT" -gt 0 ]; then
    echo -e "${GREEN}RPM packages:${NC}"
    ls -lh "${BUILD_DIR}"/${APP_PKG_NAME}-*.rpm 2>/dev/null
fi

if [ "$APPIMAGE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}AppImage packages:${NC}"
    ls -lh "${BUILD_DIR}"/${APP_NAME}-*.AppImage 2>/dev/null
    echo ""
    echo -e "${BLUE}  System Python: Run on systems with Python3 installed${NC}"
    echo -e "${BLUE}  Self-contained: Run on any Linux system (includes Python3)${NC}"
fi

if [ "$DEB_COUNT" -eq 0 ] && [ "$RPM_COUNT" -eq 0 ] && [ "$APPIMAGE_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No packages were created${NC}"
fi

echo ""
echo -e "${BLUE}Installation commands:${NC}"
if [ -f "$DEB_OUTPUT" ]; then
    echo -e "  DEB: ${GREEN}sudo dpkg -i $DEB_OUTPUT${NC}"
fi
if [ -f "$RPM_OUTPUT" ]; then
    echo -e "  RPM: ${GREEN}sudo rpm -i $RPM_OUTPUT${NC}"
fi
if [ -f "$APPIMAGE_OUTPUT" ]; then
    # Convert absolute path to relative for display
    REL_PATH=$(realpath --relative-to="$PROJECT_ROOT" "$APPIMAGE_OUTPUT")
    echo -e "  AppImage (System Python): ${GREEN}./$REL_PATH${NC}"
fi
if [ -f "$SELF_CONTAINED_OUTPUT" ]; then
    # Convert absolute path to relative for display
    REL_PATH=$(realpath --relative-to="$PROJECT_ROOT" "$SELF_CONTAINED_OUTPUT")
    echo -e "  AppImage (Self-contained): ${GREEN}./$REL_PATH${NC}"
fi
echo ""