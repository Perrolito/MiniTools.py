#!/bin/bash
# MiniTools Build Script
# Build deb, rpm, and AppImage packages directly

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
if [ -f "MiniTools.py" ]; then
    VERSION=$(grep "__version__" MiniTools.py 2>/dev/null | head -1 | cut -d'"' -f2 || echo "1.0.0")
    echo -e "${BLUE}Detected version from MiniTools.py: $VERSION${NC}"
else
    echo -e "${YELLOW}MiniTools.py not found, using default version: $VERSION${NC}"
fi

echo -e "${GREEN}Building MiniTools version: $VERSION${NC}"
echo ""

# Create build directory
BUILD_DIR="build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

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
echo "3) AppImage (Universal)"
echo "4) All formats"
echo "0) Exit"
echo ""
read -p "Enter your choice [0-4]: " choice

BUILD_DEB="false"
BUILD_RPM="false"
BUILD_APPIMAGE="false"

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
        BUILD_DEB="true"
        BUILD_RPM="true"
        BUILD_APPIMAGE="true"
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
[ "$BUILD_APPIMAGE" = "true" ] && echo -e "  ${GREEN}✓ AppImage${NC}"
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
    
    DEB_DIR="minitools_${VERSION}_amd64"
    mkdir -p "$DEB_DIR/DEBIAN"
    mkdir -p "$DEB_DIR/opt/minitools"
    mkdir -p "$DEB_DIR/usr/share/applications"
    mkdir -p "$DEB_DIR/usr/share/pixmaps"
    mkdir -p "$DEB_DIR/usr/bin"
    
    # Copy application files
    cp ../MiniTools.py "$DEB_DIR/opt/minitools/"
    chmod +x "$DEB_DIR/opt/minitools/MiniTools.py"
    
    # Copy icon if available
    if [ -f "../minitools.png" ]; then
        cp ../minitools.png "$DEB_DIR/usr/share/pixmaps/"
        echo -e "${GREEN}✓ Icon copied${NC}"
    else
        echo -e "${YELLOW}⚠ Icon not found (minitools.png), skipping...${NC}"
    fi
    
    # Create launcher script
    cat > "$DEB_DIR/usr/bin/minitools" << 'EOF'
#!/bin/bash
cd /opt/minitools
python3 MiniTools.py "$@"
EOF
    chmod +x "$DEB_DIR/usr/bin/minitools"
    
    # Create desktop entry
    cat > "$DEB_DIR/usr/share/applications/minitools.desktop" << EOF
[Desktop Entry]
Name=MiniTools
Comment=System Information and Maintenance Tools
Exec=/usr/bin/minitools
Icon=minitools
Terminal=false
Type=Application
Categories=System;Utility;
Keywords=system;monitor;maintenance;
EOF
    
    # Create control file
    cat > "$DEB_DIR/DEBIAN/control" << EOF
Package: minitools
Version: ${VERSION}
Architecture: amd64
Maintainer: MiniTools Team
Installed-Size: 1024
Section: utils
Priority: optional
Homepage: https://github.com/minitools
Description: System Information and Maintenance Tools
 MiniTools is a modern GUI application for system information
 display and maintenance. It provides tools for viewing CPU,
 memory, disk information, managing software updates, and more.
Depends: python3, python3-pyqt6
EOF
    
    # Build DEB
    dpkg-deb --build "$DEB_DIR" 2>&1
    if [ -f "${DEB_DIR}.deb" ]; then
        echo -e "${GREEN}✓ DEB package created: ${DEB_DIR}.deb${NC}"
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
    
    # Create rpmbuild directory structure
    mkdir -p rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    
    # Create spec file
    cat > rpmbuild/SPECS/minitools.spec << EOF
Name:           minitools
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        System Information and Maintenance Tools
License:        MIT
URL:            https://github.com/minitools
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
mkdir -p %{buildroot}/opt/minitools
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/applications

install -m 755 MiniTools.py %{buildroot}/opt/minitools/

cat > %{buildroot}/usr/bin/minitools << 'SCRIPT'
#!/bin/bash
cd /opt/minitools
python3 MiniTools.py "$@"
SCRIPT
chmod 755 %{buildroot}/usr/bin/minitools

cat > %{buildroot}/usr/share/applications/minitools.desktop << 'DESKTOP'
[Desktop Entry]
Name=MiniTools
Comment=System Information and Maintenance Tools
Exec=/usr/bin/minitools
Icon=minitools
Terminal=false
Type=Application
Categories=System;Utility;
DESKTOP

%files
/opt/minitools/MiniTools.py
/usr/bin/minitools
/usr/share/applications/minitools.desktop

%changelog
* $(date +'%a %b %d %Y') MiniTools Team <team@minitools.com> - ${VERSION}-1
- Initial package
EOF
    
    # Create source tarball
    mkdir -p minitools-${VERSION}
    cp ../MiniTools.py minitools-${VERSION}/
    tar -czf rpmbuild/SOURCES/minitools-${VERSION}.tar.gz minitools-${VERSION}
    
    # Build RPM
    rpmbuild -ba rpmbuild/SPECS/minitools.spec --define "_topdir $(pwd)/rpmbuild" 2>&1
    
    # Find and copy the built RPM
    if [ -f "rpmbuild/RPMS/x86_64/minitools-${VERSION}-1.x86_64.rpm" ]; then
        cp rpmbuild/RPMS/x86_64/minitools-${VERSION}-1.x86_64.rpm ./
        echo -e "${GREEN}✓ RPM package created: minitools-${VERSION}-1.x86_64.rpm${NC}"
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
    
    APPDIR="MiniTools.AppDir"
    mkdir -p "$APPDIR/usr/bin"
    mkdir -p "$APPDIR/usr/share/applications"
    mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
    
    # Copy application
    cp ../MiniTools.py "$APPDIR/usr/bin/minitools"
    chmod +x "$APPDIR/usr/bin/minitools"
    
    # Copy icon if available
    if [ -f "../minitools.png" ]; then
        # Copy to AppDir root (required by appimagetool)
        cp ../minitools.png "$APPDIR/minitools.png"
        # Also copy to system icons directory
        cp ../minitools.png "$APPDIR/usr/share/icons/hicolor/256x256/apps/minitools.png"
        echo -e "${GREEN}✓ Icon copied for AppImage${NC}"
    else
        echo -e "${YELLOW}⚠ Icon not found (minitools.png), skipping...${NC}"
    fi
    
    # Create AppRun
    cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}

# Use system Python3, not AppImage internal path
export PATH="${HERE}/usr/bin:${PATH}"
export PYTHONPATH="${HERE}/usr/lib/python3/site-packages:${PYTHONPATH}"

cd "${HERE}"
exec python3 "${HERE}/usr/bin/minitools" "$@"
EOF
    chmod +x "$APPDIR/AppRun"
    
    # Create desktop file
    cat > "$APPDIR/minitools.desktop" << 'EOF'
[Desktop Entry]
Name=MiniTools
Comment=System Information and Maintenance Tools
Exec=AppRun
Icon=minitools
Terminal=false
Type=Application
Categories=System;Utility;
EOF
    
    # Copy desktop file to AppImage location
    cp "$APPDIR/minitools.desktop" "$APPDIR/usr/share/applications/"
    
    # Download appimagetool
    APPIMAGETOOL="appimagetool-x86_64.AppImage"
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
        ARCH=x86_64 ./"$APPIMAGETOOL" "$APPDIR" "MiniTools-${VERSION}-x86_64.AppImage" 2>&1
        if [ -f "MiniTools-${VERSION}-x86_64.AppImage" ]; then
            chmod +x "MiniTools-${VERSION}-x86_64.AppImage"
            echo -e "${GREEN}✓ AppImage package created: MiniTools-${VERSION}-x86_64.AppImage${NC}"
        else
            echo -e "${RED}✗ AppImage package build failed${NC}"
        fi
    else
        echo -e "${RED}✗ appimagetool download failed${NC}"
    fi
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
if ls *.deb >/dev/null 2>&1; then
    echo -e "${GREEN}DEB packages:${NC}"
    ls -lh *.deb 2>/dev/null
fi

if ls *.rpm >/dev/null 2>&1; then
    echo -e "${GREEN}RPM packages:${NC}"
    ls -lh *.rpm 2>/dev/null
fi

if ls *.AppImage >/dev/null 2>&1; then
    echo -e "${GREEN}AppImage packages:${NC}"
    ls -lh *.AppImage 2>/dev/null
fi

if [ ! -f *.deb ] && [ ! -f *.rpm ] && [ ! -f *.AppImage ]; then
    echo -e "${YELLOW}No packages were created${NC}"
fi

echo ""
echo -e "${BLUE}Installation commands:${NC}"
if [ -f "${DEB_DIR}.deb" ]; then
    echo -e "  DEB: ${GREEN}sudo dpkg -i ${DEB_DIR}.deb${NC}"
fi
if [ -f "minitools-${VERSION}-1.x86_64.rpm" ]; then
    echo -e "  RPM: ${GREEN}sudo rpm -i minitools-${VERSION}-1.x86_64.rpm${NC}"
fi
if [ -f "MiniTools-${VERSION}-x86_64.AppImage" ]; then
    echo -e "  AppImage: ${GREEN}./MiniTools-${VERSION}-x86_64.AppImage${NC}"
fi
echo ""