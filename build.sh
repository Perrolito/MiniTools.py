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
fi

echo -e "${GREEN}Building MiniTools version: $VERSION${NC}"
echo ""

# Create build directory
BUILD_DIR="build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Clean previous builds
rm -rf *.deb *.rpm *.AppImage *.tar.gz minitools_* MiniTools.AppDir

# ============================================================================
# Build DEB Package (Debian/Ubuntu based)
# ============================================================================
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

# ============================================================================
# Build RPM Package (RHEL/Fedora based)
# ============================================================================
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

# ============================================================================
# Build AppImage
# ============================================================================
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
    
    APPDIR="MiniTools.AppDir"
    mkdir -p "$APPDIR/usr/bin"
    mkdir -p "$APPDIR/usr/share/applications"
    mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
    
    # Copy application
    cp ../MiniTools.py "$APPDIR/usr/bin/minitools"
    chmod +x "$APPDIR/usr/bin/minitools"
    
    # Create AppRun
    cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
export PYTHONPATH="${HERE}/usr/lib/python3/site-packages:${PYTHONPATH}"

cd "${HERE}"
exec "${HERE}/usr/bin/python3" "${HERE}/usr/bin/minitools" "$@"
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
    if [ ! -f "$APPIMAGETOOL" ]; then
        echo -e "${YELLOW}Downloading appimagetool...${NC}"
        wget -q --show-progress "https://github.com/AppImage/AppImageKit/releases/download/continuous/$APPIMAGETOOL"
        chmod +x "$APPIMAGETOOL"
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