#!/bin/bash
# MiniTools Build Script
# Build deb, rpm, and AppImage packages directly

set -e

# ============================================================================
# Configuration
# ============================================================================

# Get script directory (absolute path)
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Application metadata
APP_NAME="MiniTools"
APP_PKG_NAME="minitools"
APP_PYTHON_SCRIPT="MiniTools.py"
APP_ICON="minitools.png"

# Build directory
BUILD_DIR="${PROJECT_ROOT}/build"

# Path definitions
APP_SCRIPT_PATH="${PROJECT_ROOT}/${APP_PYTHON_SCRIPT}"
APP_ICON_PATH="${PROJECT_ROOT}/${APP_ICON}"

# Architecture and OS detection
ARCH=$(uname -m)
OS_TYPE=$(uname -s)
case "$OS_TYPE" in
    Linux)
        OS_SUFFIX="linux"
        ;;
    Darwin)
        OS_SUFFIX="macos"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        OS_SUFFIX="windows"
        ;;
    *)
        OS_SUFFIX="unknown"
        ;;
esac

case "$ARCH" in
    x86_64) 
        ARCH_SUFFIX="amd64"
        RPM_ARCH="x86_64"
        ;;
    aarch64) 
        ARCH_SUFFIX="aarch64"
        RPM_ARCH="x86_64"
        ;;
    arm64) 
        ARCH_SUFFIX="aarch64"
        RPM_ARCH="x86_64"
        ;;
    *) 
        ARCH_SUFFIX="$ARCH"
        RPM_ARCH="$ARCH"
        ;;
esac

# Package naming format: {pkg}-{version}-{arch}.{ext}
# AppImage format: {name}-{version}-{arch}.{type}.{ext}

# ============================================================================
# Helper Functions
# ============================================================================

# Print colored message
print_info() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

# Print section header
print_header() {
    echo ""
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo ""
}

# Check if command exists
check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get version from Python script
get_version() {
    if [ -f "$APP_SCRIPT_PATH" ]; then
        grep "__version__" "$APP_SCRIPT_PATH" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "1.0.0"
    else
        echo "1.0.0"
    fi
}

# Copy application files to directory
copy_app_files() {
    local target_dir="$1"
    local bin_dir="${target_dir}/usr/bin"
    
    mkdir -p "$bin_dir"
    
    # Copy Python script
    cp "$APP_SCRIPT_PATH" "${bin_dir}/${APP_PKG_NAME}"
    chmod +x "${bin_dir}/${APP_PKG_NAME}"
    
    # Copy icon if available
    if [ -f "$APP_ICON_PATH" ]; then
        cp "$APP_ICON_PATH" "${target_dir}/${APP_PKG_NAME}.png"
        cp "$APP_ICON_PATH" "${target_dir}/usr/share/icons/hicolor/256x256/apps/${APP_PKG_NAME}.png"
        print_success "✓ Icon copied"
    else
        print_warning "⚠ Icon not found ($APP_ICON), skipping..."
    fi
}

# Create desktop file
create_desktop_file() {
    local target_dir="$1"
    local desktop_file="${target_dir}/${APP_PKG_NAME}.desktop"
    
    cat > "$desktop_file" << EOF
[Desktop Entry]
Name=$APP_NAME
Comment=System Information and Maintenance Tools
Exec=AppRun
Icon=$APP_PKG_NAME
Terminal=false
Type=Application
Categories=System;Utility;
EOF
    
    # Also copy to standard location
    mkdir -p "${target_dir}/usr/share/applications"
    cp "$desktop_file" "${target_dir}/usr/share/applications/"
}

# Create AppRun script
create_apprun() {
    local target_dir="$1"
    local python_runtime="${2:-}"
    
    cat > "${target_dir}/AppRun" << EOF
#!/bin/bash
SELF=\$(readlink -f "\$0")
HERE=\${SELF%/*}

${python_runtime}
cd "\${HERE}"
exec "\${HERE}/usr/bin/$APP_PKG_NAME" "\$@"
EOF
    
    chmod +x "${target_dir}/AppRun"
}

# Find appimagetool
find_appimagetool() {
    local tool="appimagetool-x86_64.AppImage"
    
    if [ -f "${BUILD_DIR}/${tool}" ]; then
        echo "${BUILD_DIR}/${tool}"
    elif [ -f "./${tool}" ]; then
        echo "./${tool}"
    else
        echo ""
    fi
}

# Convert SVG to ICNS (macOS only)
convert_svg_to_icns() {
    local svg_file="$1"
    local icns_file="$2"
    
    if [ "$OS_TYPE" != "Darwin" ]; then
        print_error "Error: SVG to ICNS conversion only works on macOS"
        return 1
    fi
    
    if [ ! -f "$svg_file" ]; then
        print_error "Error: SVG file not found: $svg_file"
        return 1
    fi
    
    # Check for ImageMagick or Inkscape
    if check_command convert; then
        print_info "Converting SVG to ICNS using ImageMagick..."
        convert "$svg_file" -define icon:auto-resize=1024,512,256,128,64,32,16 "$icns_file"
    elif check_command inkscape; then
        print_info "Converting SVG to ICNS using Inkscape..."
        local iconset_dir="${BUILD_DIR}/${APP_PKG_NAME}.iconset"
        mkdir -p "$iconset_dir"
        
        # Export different sizes
        local sizes=(1024 512 256 128 64 32 16)
        for size in "${sizes[@]}"; do
            inkscape --export-type=png --export-filename="${iconset_dir}/icon_${size}.png" -w "$size" -h "$size" "$svg_file"
        done
        
        # Create iconset structure
        cp "${iconset_dir}/icon_1024.png" "${iconset_dir}/icon_512x512@2x.png"
        cp "${iconset_dir}/icon_512.png" "${iconset_dir}/icon_512x512.png"
        cp "${iconset_dir}/icon_256.png" "${iconset_dir}/icon_256x256@2x.png"
        cp "${iconset_dir}/icon_128.png" "${iconset_dir}/icon_128x128.png"
        cp "${iconset_dir}/icon_64.png" "${iconset_dir}/icon_64x64@2x.png"
        cp "${iconset_dir}/icon_32.png" "${iconset_dir}/icon_32x32.png"
        cp "${iconset_dir}/icon_16.png" "${iconset_dir}/icon_16x16.png"
        
        # Convert to ICNS
        iconutil -c icns "$iconset_dir" -o "$icns_file"
        
        # Cleanup
        rm -rf "$iconset_dir"
    else
        print_error "Error: Neither ImageMagick nor Inkscape found"
        print_info "Install ImageMagick: brew install imagemagick"
        print_info "Or install Inkscape: brew install --cask inkscape"
        return 1
    fi
    
    if [ -f "$icns_file" ]; then
        print_success "✓ ICNS file created: $icns_file"
        return 0
    else
        print_error "✗ Failed to create ICNS file"
        return 1
    fi
}

# Print usage
print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build MiniTools packages for Linux, macOS, and Windows.

OPTIONS:
    -f, --format FORMAT     Build format: deb, rpm, appimage, self-contained, macos, dmg, all
    -h, --help              Show this help message
    -n, --non-interactive   Run in non-interactive mode (requires -f)

EXAMPLES:
    $0                      Interactive mode (select format from menu)
    $0 -f deb              Build DEB package only
    $0 -f appimage          Build AppImage (system Python)
    $0 -f self-contained    Build self-contained AppImage
    $0 -f macos             Build macOS .app bundle (macOS only)
    $0 -f dmg               Build macOS .app + .dmg (macOS only)
    $0 -f all               Build all package formats for current platform    $0 -f appimage -n       Build AppImage in non-interactive mode

SUPPORTED FORMATS:
    Linux:
        deb                    DEB package (Debian/Ubuntu)
        rpm                    RPM package (Fedora/RHEL)
        appimage               AppImage (requires system Python3)
        self-contained         AppImage (includes Python3 and PyQt6)
    
    macOS:
        macos                  .app bundle
        dmg                    .dmg installer (.app + .dmg)

REQUIREMENTS:
    Linux DEB:  dpkg-deb
    Linux RPM:  rpmbuild
    AppImage: appimagetool + system Python3 + PyQt6
    Self-contained: appimagetool + PyInstaller
    macOS: PyInstaller + ImageMagick/Inkscape (for SVG to ICNS)
    DMG: dmgbuild (optional, for creating .dmg installer)

NOTES:
    macOS packages can only be built on macOS
    For cross-platform builds, use GitHub Actions with appropriate runners
    For Windows builds, use build.bat on Windows
EOF
}

# ============================================================================
# Initialization
# ============================================================================

# Parse command line arguments
BUILD_DEB="false"
BUILD_RPM="false"
BUILD_APPIMAGE="false"
BUILD_APPIMAGE_BUNDLE="false"
BUILD_MACOS="false"
BUILD_MACOS_DMG="false"
INTERACTIVE="true"

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--format)
            if [ -z "$2" ]; then
                print_error "Error: --format requires an argument"
                exit 1
            fi
            case "$2" in
                deb)
                    BUILD_DEB="true"
                    INTERACTIVE="false"
                    ;;
                rpm)
                    BUILD_RPM="true"
                    INTERACTIVE="false"
                    ;;
                appimage)
                    BUILD_APPIMAGE="true"
                    INTERACTIVE="false"
                    ;;
                self-contained)
                    BUILD_APPIMAGE_BUNDLE="true"
                    INTERACTIVE="false"
                    ;;
                macos)
                    BUILD_MACOS="true"
                    BUILD_MACOS_DMG="false"
                    INTERACTIVE="false"
                    ;;
                dmg)
                    BUILD_MACOS="true"
                    BUILD_MACOS_DMG="true"
                    INTERACTIVE="false"
                    ;;
                all)
                    if [ "$OS_TYPE" = "Darwin" ]; then
                        BUILD_MACOS="true"
                        BUILD_MACOS_DMG="true"
                    else
                        BUILD_DEB="true"
                        BUILD_RPM="true"
                        BUILD_APPIMAGE="true"
                        BUILD_APPIMAGE_BUNDLE="true"
                    fi
                    INTERACTIVE="false"
                    ;;
                *)
                    print_error "Error: Unknown format '$2'"
                    print_usage
                    exit 1
                    ;;
            esac
            shift 2
            ;;
        -n|--non-interactive)
            INTERACTIVE="false"
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            print_error "Error: Unknown option '$1'"
            print_usage
            exit 1
            ;;
    esac
done

print_header "MiniTools Build Script"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Error: Don't run this script as root"
    exit 1
fi

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
else
    DISTRO="unknown"
fi
print_info "Detected distribution: $DISTRO"

# Get version
VERSION=$(get_version)
print_info "Detected version from $APP_PYTHON_SCRIPT: $VERSION"
print_success "Building MiniTools version: $VERSION"

# Create build directory
mkdir -p "$BUILD_DIR"

# ============================================================================
# Interactive Menu (if needed)
# ============================================================================

if [ "$INTERACTIVE" = "true" ]; then
    print_header "Select Build Format"
    echo ""
    
    # Determine supported formats
    CAN_BUILD_DEB="true"
    CAN_BUILD_RPM="true"
    CAN_BUILD_APPIMAGE="true"
    CAN_BUILD_BUNDLE="true"
    CAN_BUILD_MACOS="false"
    CAN_BUILD_MACOS_DMG="false"
    
    if [ "$OS_TYPE" = "Darwin" ]; then
        CAN_BUILD_DEB="false"
        CAN_BUILD_RPM="false"
        CAN_BUILD_APPIMAGE="false"
        CAN_BUILD_BUNDLE="false"
        CAN_BUILD_MACOS="true"
        CAN_BUILD_MACOS_DMG="true"
    fi
    
    # Display menu with availability status
    if [ "$CAN_BUILD_DEB" = "true" ]; then
        echo -e "  ${GREEN}1)${NC} DEB Package (Debian/Ubuntu)"
    else
        echo -e "  ${GRAY}1)${NC} DEB Package (Debian/Ubuntu) ${GRAY}[macOS not supported]${NC}"
    fi
    
    if [ "$CAN_BUILD_RPM" = "true" ]; then
        echo -e "  ${GREEN}2)${NC} RPM Package (Fedora/RHEL)"
    else
        echo -e "  ${GRAY}2)${NC} RPM Package (Fedora/RHEL) ${GRAY}[macOS not supported]${NC}"
    fi
    
    if [ "$CAN_BUILD_APPIMAGE" = "true" ]; then
        echo -e "  ${GREEN}3)${NC} AppImage (Universal, requires system Python3)"
    else
        echo -e "  ${GRAY}3)${NC} AppImage (Universal) ${GRAY}[macOS not supported]${NC}"
    fi
    
    if [ "$CAN_BUILD_BUNDLE" = "true" ]; then
    
            echo -e "  ${GREEN}4)${NC} AppImage (Self-contained, includes Python3)"
    
        else
    
            echo -e "  ${GRAY}4)${NC} AppImage (Self-contained) ${GRAY}[$OS_TYPE not supported]${NC}"
    
        fi
    
        
    
        echo ""
    
        
    
        if [ "$CAN_BUILD_MACOS" = "true" ]; then
    
            echo -e "  ${GREEN}5)${NC} macOS App Bundle (.app)"
    
            echo -e "  ${GREEN}6)${NC} macOS DMG Installer (.app + .dmg)"
    
        else
    
            echo -e "  ${GRAY}5)${NC} macOS App Bundle (.app) ${GRAY}[$OS_TYPE not supported]${NC}"
    
            echo -e "  ${GRAY}6)${NC} macOS DMG Installer (.dmg) ${GRAY}[$OS_TYPE not supported]${NC}"
    
        fi
    
            
    
            echo ""
    
            echo "7) All formats"
    
            echo "0) Exit"
    
            echo ""
    
            
    
            # Show platform
    
            print_info "Current platform: $OS_TYPE ($ARCH)"
    
            echo ""
    
            
    
            read -p "Enter your choice [0-7]: " choice

    case $choice in
        1)
            if [ "$CAN_BUILD_DEB" = "true" ]; then
                BUILD_DEB="true"
            else
                print_error "Error: DEB packages cannot be built on $OS_TYPE"
                print_info "Please run this script on a Linux system"
                exit 1
            fi
            ;;
        2)
            if [ "$CAN_BUILD_RPM" = "true" ]; then
                BUILD_RPM="true"
            else
                print_error "Error: RPM packages cannot be built on $OS_TYPE"
                print_info "Please run this script on a Linux system"
                exit 1
            fi
            ;;
        3)
            if [ "$CAN_BUILD_APPIMAGE" = "true" ]; then
                BUILD_APPIMAGE="true"
            else
                print_error "Error: AppImage cannot be built on $OS_TYPE"
                print_info "Please run this script on a Linux system"
                exit 1
            fi
            ;;
        4)
            if [ "$CAN_BUILD_BUNDLE" = "true" ]; then
                BUILD_APPIMAGE_BUNDLE="true"
            else
                print_error "Error: Self-contained AppImage cannot be built on $OS_TYPE"
                print_info "Please run this script on a Linux system"
                exit 1
            fi
            ;;
        5)
            if [ "$CAN_BUILD_MACOS" = "true" ]; then
                BUILD_MACOS="true"
                BUILD_MACOS_DMG="false"
            else
                print_error "Error: macOS packages cannot be built on $OS_TYPE"
                print_info "Please run this script on macOS"
                print_info "Or use GitHub Actions with macOS runner for cross-platform builds"
                exit 1
            fi
            ;;
        6)
            if [ "$CAN_BUILD_MACOS" = "true" ]; then
                BUILD_MACOS="true"
                BUILD_MACOS_DMG="true"
            else
                print_error "Error: macOS packages cannot be built on $OS_TYPE"
                print_info "Please run this script on macOS"
                print_info "Or use GitHub Actions with macOS runner for cross-platform builds"
                exit 1
            fi
            ;;
        7)
            if [ "$CAN_BUILD_DEB" = "true" ]; then BUILD_DEB="true"; fi
            if [ "$CAN_BUILD_RPM" = "true" ]; then BUILD_RPM="true"; fi
            if [ "$CAN_BUILD_APPIMAGE" = "true" ]; then BUILD_APPIMAGE="true"; fi
            if [ "$CAN_BUILD_BUNDLE" = "true" ]; then BUILD_BUNDLE="true"; fi
            if [ "$CAN_BUILD_MACOS" = "true" ]; then BUILD_MACOS="true"; fi
            if [ "$CAN_BUILD_MACOS_DMG" = "true" ]; then BUILD_MACOS_DMG="true"; fi
            ;;
        0)
            print_warning "Build cancelled"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
fi

# Print what will be built
echo ""
print_info "Building formats:"
[ "$BUILD_DEB" = "true" ] && echo -e "  ${GREEN}✓ DEB${NC}"
[ "$BUILD_RPM" = "true" ] && echo -e "  ${GREEN}✓ RPM${NC}"
[ "$BUILD_APPIMAGE" = "true" ] && echo -e "  ${GREEN}✓ AppImage (System Python)${NC}"
[ "$BUILD_APPIMAGE_BUNDLE" = "true" ] && echo -e "  ${GREEN}✓ AppImage (Self-contained)${NC}"
[ "$BUILD_MACOS" = "true" ] && echo -e "  ${GREEN}✓ macOS App Bundle${NC}"
[ "$BUILD_MACOS_DMG" = "true" ] && echo -e "  ${GREEN}✓ macOS DMG Installer${NC}"
echo ""

# ============================================================================
# Build DEB Package
# ============================================================================

if [ "$BUILD_DEB" = "true" ]; then
    print_header "Building DEB Package"
    
    if check_command dpkg-deb; then
        print_success "✓ dpkg-deb found"
    else
        print_error "✗ dpkg-deb not found - skipping DEB build"
        print_info "  Install with: sudo apt install dpkg-dev"
        BUILD_DEB="false"
    fi
    
    if [ "$BUILD_DEB" = "true" ]; then
        # Setup paths
        DEB_OUTPUT="${BUILD_DIR}/${APP_PKG_NAME}-${VERSION}-${ARCH_SUFFIX}.deb"
        DEB_DIR="${BUILD_DIR}/${APP_PKG_NAME}_${VERSION}_${ARCH_SUFFIX}"
        DEB_INSTALL_DIR="/opt/${APP_PKG_NAME}"
        
        # Clean up previous build
        print_info "Cleaning up previous DEB build artifacts..."
        rm -rf "$DEB_DIR"
        rm -f "$DEB_OUTPUT"
        
        # Create directory structure
        mkdir -p "${DEB_DIR}/DEBIAN"
        mkdir -p "${DEB_DIR}${DEB_INSTALL_DIR}"
        mkdir -p "${DEB_DIR}/usr/share/applications"
        mkdir -p "${DEB_DIR}/usr/share/pixmaps"
        mkdir -p "${DEB_DIR}/usr/bin"
        
        # Copy application files
        cp "$APP_SCRIPT_PATH" "${DEB_DIR}${DEB_INSTALL_DIR}/${APP_PYTHON_SCRIPT}"
        chmod +x "${DEB_DIR}${DEB_INSTALL_DIR}/${APP_PYTHON_SCRIPT}"
        
        # Copy icon
        if [ -f "$APP_ICON_PATH" ]; then
            cp "$APP_ICON_PATH" "${DEB_DIR}/usr/share/pixmaps/${APP_PKG_NAME}.png"
            print_success "✓ Icon copied"
        fi
        
        # Create launcher script
        cat > "${DEB_DIR}/usr/bin/${APP_PKG_NAME}" << EOF
#!/bin/bash
cd ${DEB_INSTALL_DIR}
python3 ${APP_PYTHON_SCRIPT} "\$@"
EOF
        chmod +x "${DEB_DIR}/usr/bin/${APP_PKG_NAME}"
        
        # Create desktop entry
        cat > "${DEB_DIR}/usr/share/applications/${APP_PKG_NAME}.desktop" << EOF
[Desktop Entry]
Name=$APP_NAME
Comment=System Information and Maintenance Tools
Exec=/usr/bin/${APP_PKG_NAME}
Icon=${APP_PKG_NAME}
Terminal=false
Type=Application
Categories=System;Utility;
Keywords=system;monitor;maintenance;
EOF
        
        # Create control file
        cat > "${DEB_DIR}/DEBIAN/control" << EOF
Package: ${APP_PKG_NAME}
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
            print_success "✓ DEB package created: $DEB_OUTPUT"
        else
            print_error "✗ DEB package build failed"
        fi
    fi
fi

# ============================================================================
# Build RPM Package
# ============================================================================

if [ "$BUILD_RPM" = "true" ]; then
    print_header "Building RPM Package"
    
    if check_command rpmbuild; then
        print_success "✓ rpmbuild found"
    else
        print_error "✗ rpmbuild not found - skipping RPM build"
        print_info "  Install with: sudo dnf install rpm-build"
        BUILD_RPM="false"
    fi
    
    if [ "$BUILD_RPM" = "true" ]; then
        # Setup paths
        RPM_OUTPUT="${BUILD_DIR}/${APP_PKG_NAME}-${VERSION}-${ARCH_SUFFIX}.rpm"
        
        # Create rpmbuild directory structure
        mkdir -p "${BUILD_DIR}/rpmbuild/BUILD" "${BUILD_DIR}/rpmbuild/RPMS" "${BUILD_DIR}/rpmbuild/SOURCES" "${BUILD_DIR}/rpmbuild/SPECS" "${BUILD_DIR}/rpmbuild/SRPMS"
        RPM_RPMS_DIR="${BUILD_DIR}/rpmbuild/RPMS/${RPM_ARCH}"
        
        # Create spec file
        cat > "${BUILD_DIR}/rpmbuild/SPECS/${APP_PKG_NAME}.spec" << EOF
Name:           ${APP_PKG_NAME}
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        System Information and Maintenance Tools
License:        MIT
URL:            https://github.com/Perrolito/MiniTools.py/
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  python3-devel, python3-pyqt6-devel
Requires:       python3, python3-pyqt6

%global debug_package %{nil}

%description
MiniTools is a modern GUI application for system information
display and maintenance. It provides tools for viewing CPU,
memory, disk information, managing software updates, and more.

%prep
%setup -q

%build
# No build needed for Python script

%install
mkdir -p %{buildroot}/opt/${APP_PKG_NAME}
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/applications

install -m 755 ${APP_PYTHON_SCRIPT} %{buildroot}/opt/${APP_PKG_NAME}/

cat > %{buildroot}/usr/bin/${APP_PKG_NAME} << SCRIPT
#!/bin/bash
cd /opt/${APP_PKG_NAME}
python3 ${APP_PYTHON_SCRIPT} "\$@"
SCRIPT
chmod 755 %{buildroot}/usr/bin/${APP_PKG_NAME}

cat > %{buildroot}/usr/share/applications/${APP_PKG_NAME}.desktop << DESKTOP
[Desktop Entry]
Name=$APP_NAME
Comment=System Information and Maintenance Tools
Exec=/usr/bin/${APP_PKG_NAME}
Icon=${APP_PKG_NAME}
Terminal=false
Type=Application
Categories=System;Utility;
DESKTOP

%files
/opt/${APP_PKG_NAME}/${APP_PYTHON_SCRIPT}
/usr/bin/${APP_PKG_NAME}
/usr/share/applications/${APP_PKG_NAME}.desktop

%changelog
* $(date +'%a %b %d %Y') MiniTools Team <team@minitools.com> - ${VERSION}-1
- Initial package
EOF
        
        # Create source tarball
        mkdir -p "${BUILD_DIR}/${APP_PKG_NAME}-${VERSION}"
        cp "$APP_SCRIPT_PATH" "${BUILD_DIR}/${APP_PKG_NAME}-${VERSION}/"
        tar -czf "${BUILD_DIR}/rpmbuild/SOURCES/${APP_PKG_NAME}-${VERSION}.tar.gz" -C "${BUILD_DIR}" "${APP_PKG_NAME}-${VERSION}"
        
        # Build RPM
        rpmbuild_topdir="${BUILD_DIR}/rpmbuild"
        rpmbuild -ba "${BUILD_DIR}/rpmbuild/SPECS/${APP_PKG_NAME}.spec" --define "_topdir ${rpmbuild_topdir}" 2>&1
        
        # Find and copy the built RPM (file may include dist info like .fc43)
        RPM_FILE=$(find "${RPM_RPMS_DIR}" -name "${APP_PKG_NAME}-${VERSION}-1.*.${RPM_ARCH}.rpm" 2>/dev/null | head -1)
        if [ -n "$RPM_FILE" ] && [ -f "$RPM_FILE" ]; then
            cp "$RPM_FILE" "$RPM_OUTPUT"
            print_success "✓ RPM package created: $RPM_OUTPUT"
        else
            print_error "✗ RPM package build failed"
            print_info "  Looking for: ${APP_PKG_NAME}-${VERSION}-1.*.${RPM_ARCH}.rpm in ${RPM_RPMS_DIR}"
        fi
    fi
fi

# ============================================================================
# Build AppImage (System Python)
# ============================================================================

if [ "$BUILD_APPIMAGE" = "true" ]; then
    print_header "Building AppImage Package"
    
    if check_command wget; then
        print_success "✓ wget found"
    else
        print_error "✗ wget not found - skipping AppImage build"
        print_info "  Install with: sudo apt install wget"
        BUILD_APPIMAGE="false"
    fi
    
    if [ "$BUILD_APPIMAGE" = "true" ]; then
        print_warning "Note: This AppImage requires Python3 to be installed on the target system"
        print_warning "For a self-contained AppImage with Python, use the self-contained option"
        echo ""
        
        # Setup paths
        WORKDIR="${BUILD_DIR}/${APP_PKG_NAME}-${VERSION}-${ARCH_SUFFIX}-appimage"
        APPDIR="${WORKDIR}/AppDir"
        APPIMAGE_OUTPUT="${BUILD_DIR}/${APP_PKG_NAME}-${VERSION}-${ARCH_SUFFIX}.AppImage"
        APPIMAGETOOL=$(find_appimagetool)
        APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
        
        # Check for appimagetool
        if [ -z "$APPIMAGETOOL" ]; then
            print_error "✗ appimagetool not found"
            print_info "Download appimagetool to build directory:"
            print_info "  wget $APPIMAGETOOL_URL -P build/"
            print_info "  chmod +x build/appimagetool-x86_64.AppImage"
            print_info ""
            print_info "Or run: ./download-build-tools.sh"
            BUILD_APPIMAGE="false"
        fi
        
        if [ "$BUILD_APPIMAGE" = "true" ]; then
            # Clean up previous build
            print_info "Cleaning up previous AppImage build artifacts..."
            rm -rf "$WORKDIR"
            rm -f "$APPIMAGE_OUTPUT"
            
            # Create directory structure
            mkdir -p "$APPDIR/usr/bin"
            mkdir -p "$APPDIR/usr/share/applications"
            mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
            
            # Copy application
            copy_app_files "$APPDIR"
            
            # Create AppRun
            cat > "$APPDIR/AppRun" << EOF
#!/bin/bash
SELF=\$(readlink -f "\$0")
HERE=\${SELF%/*}

# Use system Python3, not AppImage internal path
export PATH="\${HERE}/usr/bin:\${PATH}"
export PYTHONPATH="\${HERE}/usr/lib/python3/site-packages:\${PYTHONPATH}"

cd "\${HERE}"
exec python3 "\${HERE}/usr/bin/${APP_PKG_NAME}" "\$@"
EOF
            chmod +x "$APPDIR/AppRun"
            
            # Create desktop file
            create_desktop_file "$APPDIR"
            
            # Download appimagetool if needed
            print_info "Checking appimagetool..."
            NEED_DOWNLOAD=true
            
            if [ -f "$APPIMAGETOOL" ]; then
                print_success "✓ appimagetool already exists"
                print_info "  File: $APPIMAGETOOL"
                print_info "  Size: $(du -h "$APPIMAGETOOL" | cut -f1)"
                echo ""
                if [ "$INTERACTIVE" = "true" ]; then
                    read -p "Press Enter to use existing file, or type 'y' to re-download: " redownload
                    echo ""
                    if [[ "$redownload" =~ ^[Yy]$ ]]; then
                        print_warning "Re-downloading appimagetool..."
                        rm -f "$APPIMAGETOOL"
                        NEED_DOWNLOAD=true
                    else
                        print_success "Using existing file"
                        NEED_DOWNLOAD=false
                    fi
                else
                    NEED_DOWNLOAD=false
                fi
            fi
            
            if [ "$NEED_DOWNLOAD" = true ]; then
                print_warning "Downloading appimagetool..."
                print_info "  Download URL: $APPIMAGETOOL_URL"
                print_info "  Save location: $APPIMAGETOOL"
                wget --show-progress -O "$APPIMAGETOOL" "$APPIMAGETOOL_URL"
                if [ -f "$APPIMAGETOOL" ] && [ -s "$APPIMAGETOOL" ]; then
                    chmod +x "$APPIMAGETOOL"
                    print_success "✓ Download completed"
                else
                    print_error "✗ Download failed"
                fi
            fi
            
            # Build AppImage
            if [ -f "$APPIMAGETOOL" ]; then
                ARCH=x86_64 "$APPIMAGETOOL" "$APPDIR" "$APPIMAGE_OUTPUT" 2>&1
                if [ -f "$APPIMAGE_OUTPUT" ]; then
                    chmod +x "$APPIMAGE_OUTPUT"
                    print_success "✓ AppImage package created: $APPIMAGE_OUTPUT"
                else
                    print_error "✗ AppImage package build failed"
                fi
            else
                print_error "✗ appimagetool download failed"
            fi
        fi
    fi
fi

# ============================================================================
# Build Self-Contained AppImage (PyInstaller)
# ============================================================================

if [ "$BUILD_APPIMAGE_BUNDLE" = "true" ]; then
    print_header "Building Self-Contained AppImage Package"
    
    print_warning "Note: This will use PyInstaller to bundle the application"
    print_warning "      This will create a much larger AppImage but works on any system"
    echo ""
    
    # Check for appimagetool
    APPIMAGETOOL=$(find_appimagetool)
    if [ -z "$APPIMAGETOOL" ]; then
        print_error "✗ appimagetool not found"
        print_info "Download appimagetool to build directory:"
        print_info "  wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -P build/"
        print_info "  chmod +x build/appimagetool-x86_64.AppImage"
        print_info ""
        print_info "Or run: ./download-build-tools.sh"
        BUILD_APPIMAGE_BUNDLE="false"
    fi
    
    # Check for PyInstaller
    if [ "$BUILD_APPIMAGE_BUNDLE" = "true" ]; then
        if ! check_command pyinstaller; then
            print_error "✗ PyInstaller not found"
            print_info "Install PyInstaller:"
            print_info "  pip install pyinstaller"
            BUILD_APPIMAGE_BUNDLE="false"
        fi
    fi
    
    if [ "$BUILD_APPIMAGE_BUNDLE" = "true" ]; then
        # Setup paths
        SELF_CONTAINED_APPDIR="${BUILD_DIR}/${APP_PKG_NAME}-${VERSION}-${ARCH_SUFFIX}-self-contained-appimage"
        SELF_CONTAINED_OUTPUT="${BUILD_DIR}/${APP_PKG_NAME}-${VERSION}-${ARCH_SUFFIX}-self-contained.AppImage"
        PYINSTALLER_DIR="${SELF_CONTAINED_APPDIR}/pyinstaller"
        APPDIR="${SELF_CONTAINED_APPDIR}/AppDir"
        
        # Clean up previous build
        print_info "Cleaning up previous Self-Contained AppImage build artifacts..."
        rm -rf "$SELF_CONTAINED_APPDIR"
        rm -f "$SELF_CONTAINED_OUTPUT"
        
        # Create directory structure
        mkdir -p "$APPDIR/usr/bin"
        mkdir -p "$APPDIR/usr/share/applications"
        mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
        
        # Build with PyInstaller
        print_info "Building with PyInstaller..."
        pyinstaller --onefile \
            --name "$APP_PKG_NAME" \
            --distpath "$APPDIR/usr/bin" \
            --workpath "$PYINSTALLER_DIR" \
            --specpath "$PYINSTALLER_DIR" \
            --icon="$APP_ICON_PATH" \
            --windowed \
            --hidden-import=PyQt6 \
            --hidden-import=PyQt6.QtCore \
            --hidden-import=PyQt6.QtGui \
            --hidden-import=PyQt6.QtWidgets \
            "$APP_SCRIPT_PATH"
        
        if [ ! -f "$APPDIR/usr/bin/$APP_PKG_NAME" ]; then
            print_error "✗ PyInstaller build failed"
            BUILD_APPIMAGE_BUNDLE="false"
        fi
    fi
    
    if [ "$BUILD_APPIMAGE_BUNDLE" = "true" ]; then
        # Copy icon
        if [ -f "$APP_ICON_PATH" ]; then
            cp "$APP_ICON_PATH" "$APPDIR/$APP_PKG_NAME.png"
            cp "$APP_ICON_PATH" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$APP_PKG_NAME.png"
        fi
        
        # Create AppRun
        cat > "$APPDIR/AppRun" << EOF
#!/bin/bash
SELF=\$(readlink -f "\$0")
HERE=\${SELF%/*}

cd "\${HERE}"
exec "\${HERE}/usr/bin/$APP_PKG_NAME" "\$@"
EOF
        chmod +x "$APPDIR/AppRun"
        
        # Create desktop file
        create_desktop_file "$APPDIR"
        
        # Build AppImage using appimagetool
        print_info "Building AppImage with appimagetool..."
        ARCH=x86_64 "$APPIMAGETOOL" "$APPDIR" "$SELF_CONTAINED_OUTPUT" 2>&1
        
        if [ -f "$SELF_CONTAINED_OUTPUT" ]; then
            chmod +x "$SELF_CONTAINED_OUTPUT"
            print_success "✓ Self-contained AppImage created: $SELF_CONTAINED_OUTPUT"
        else
            print_error "✗ Self-contained AppImage build failed"
        fi
        
        # Clean up PyInstaller build directory (interactive)
        if [ -d "$PYINSTALLER_DIR" ]; then
            print_info "PyInstaller work directory preserved at: $PYINSTALLER_DIR"
            print_info "Contains analysis results and build artifacts useful for debugging"
            if [ "$INTERACTIVE" = "true" ]; then
                echo ""
                read -p "Clean up PyInstaller work directory? [y/N]: " cleanup_response
                if [[ "$cleanup_response" =~ ^[Yy]$ ]]; then
                    rm -rf "$PYINSTALLER_DIR"
                    print_success "✓ PyInstaller work directory cleaned"
                else
                    print_info "PyInstaller work directory kept for debugging"
                fi
            fi
        fi
    fi
fi

# ============================================================================
# Build macOS App Bundle
# ============================================================================

if [ "$BUILD_MACOS" = "true" ]; then
    print_header "Building macOS App Bundle"
    
    if [ "$OS_TYPE" != "Darwin" ]; then
        print_error "Error: macOS packages can only be built on macOS"
        print_info "Use GitHub Actions or a macOS machine to build macOS packages"
        BUILD_MACOS="false"
    fi
    
    if [ "$BUILD_MACOS" = "true" ]; then
        # Check for PyInstaller
        if ! check_command pyinstaller; then
            print_error "✗ PyInstaller not found"
            print_info "Install PyInstaller: pip install pyinstaller"
            BUILD_MACOS="false"
        fi
    fi
    
    if [ "$BUILD_MACOS" = "true" ]; then
        # Setup paths
        MACOS_APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
        MACOS_OUTPUT="${BUILD_DIR}/${APP_PKG_NAME}-${VERSION}-${ARCH_SUFFIX}.app"
        DMG_OUTPUT="${BUILD_DIR}/${APP_PKG_NAME}-${VERSION}-${ARCH_SUFFIX}.dmg"
        ICNS_FILE="${BUILD_DIR}/${APP_PKG_NAME}.icns"
        
        # Clean up previous build
        print_info "Cleaning up previous macOS build artifacts..."
        rm -rf "$MACOS_APP_DIR"
        rm -rf "$MACOS_OUTPUT"
        rm -f "$DMG_OUTPUT"
        rm -f "$ICNS_FILE"
        
        # Convert SVG to ICNS if needed
        if [ -f "$APP_ICON_PATH" ] && [[ "$APP_ICON_PATH" == *.svg ]]; then
            if ! convert_svg_to_icns "$APP_ICON_PATH" "$ICNS_FILE"; then
                print_warning "Failed to convert SVG to ICNS, will build without icon"
                ICNS_FILE=""
            fi
        elif [ -f "$APP_ICON_PATH" ] && [[ "$APP_ICON_PATH" == *.icns ]]; then
            cp "$APP_ICON_PATH" "$ICNS_FILE"
        fi
        
        # Build .app bundle with PyInstaller
        print_info "Building .app bundle with PyInstaller..."
        local pyinstaller_args=(
            --windowed
            --name "$APP_PKG_NAME"
            --distpath "$BUILD_DIR"
            --icon="$ICNS_FILE"
            --hidden-import=PyQt6
            --hidden-import=PyQt6.QtCore
            --hidden-import=PyQt6.QtGui
            --hidden-import=PyQt6.QtWidgets
            "$APP_SCRIPT_PATH"
        )
        
        if [ -n "$ICNS_FILE" ]; then
            pyinstaller_args+=(--icon="$ICNS_FILE")
        fi
        
        pyinstaller "${pyinstaller_args[@]}"
        
        # PyInstaller creates ${BUILD_DIR}/${APP_PKG_NAME}.app
        if [ -d "${BUILD_DIR}/${APP_PKG_NAME}.app" ]; then
            # Rename to standard format
            mv "${BUILD_DIR}/${APP_PKG_NAME}.app" "$MACOS_OUTPUT"
            print_success "✓ .app bundle created: $MACOS_OUTPUT"
        else
            print_error "✗ Failed to create .app bundle"
            BUILD_MACOS="false"
        fi
    fi
    
    # Create DMG if requested
    if [ "$BUILD_MACOS" = "true" ] && [ "$BUILD_MACOS_DMG" = "true" ]; then
        if check_command dmgbuild; then
            print_info "Creating DMG installer..."
            
            # Create dmgbuild config
            local dmg_config="${BUILD_DIR}/dmg_settings.py"
            cat > "$dmg_config" << EOF
format = 'UDBZ'
volume_name = '${APP_NAME}'
files = ['$MACOS_OUTPUT']
symlinks = {'Applications': '/Applications'}
icon_locations = {
    '$MACOS_OUTPUT': (100, 120)
}
icon_size = 80
window_rect = ((100, 100), (640, 480))
default_view = 'icon-view'
show_icon_view_paths = ['Applications']
EOF
            
            dmgbuild -s "$dmg_config" "$APP_NAME" "$DMG_OUTPUT"
            
            if [ -f "$DMG_OUTPUT" ]; then
                print_success "✓ DMG installer created: $DMG_OUTPUT"
            else
                print_error "✗ Failed to create DMG installer"
            fi
            
            rm -f "$dmg_config"
        else
            print_warning "⚠ dmgbuild not found, skipping DMG creation"
            print_info "Install dmgbuild: pip install dmgbuild"
        fi
    fi
fi

# ============================================================================
# Summary
# ============================================================================

print_header "Build Summary"
print_info "Packages created in: $BUILD_DIR"
echo ""

# Count created packages
DEB_COUNT=$(ls "${BUILD_DIR}"/${APP_PKG_NAME}-*.deb 2>/dev/null | wc -l)
RPM_COUNT=$(ls "${BUILD_DIR}"/${APP_PKG_NAME}-*.rpm 2>/dev/null | wc -l)
APPIMAGE_COUNT=$(ls "${BUILD_DIR}"/${APP_PKG_NAME}-*.AppImage 2>/dev/null | wc -l)
MACOS_APP_COUNT=$(ls "${BUILD_DIR}"/${APP_PKG_NAME}-*.app 2>/dev/null | wc -l)
MACOS_DMG_COUNT=$(ls "${BUILD_DIR}"/${APP_PKG_NAME}-*.dmg 2>/dev/null | wc -l)

# List created packages
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
    ls -lh "${BUILD_DIR}"/${APP_PKG_NAME}-*.AppImage 2>/dev/null
    echo ""
    print_info "  System Python: Run on systems with Python3 installed"
    print_info "  Self-contained: Run on any Linux system (includes Python3)"
fi

if [ "$MACOS_APP_COUNT" -gt 0 ]; then
    echo -e "${GREEN}macOS packages:${NC}"
    ls -lh "${BUILD_DIR}"/${APP_PKG_NAME}-*.app 2>/dev/null
    if [ "$MACOS_DMG_COUNT" -gt 0 ]; then
        ls -lh "${BUILD_DIR}"/${APP_PKG_NAME}-*.dmg 2>/dev/null
    fi
fi

if [ "$DEB_COUNT" -eq 0 ] && [ "$RPM_COUNT" -eq 0 ] && [ "$APPIMAGE_COUNT" -eq 0 ] && [ "$MACOS_APP_COUNT" -eq 0 ]; then
    print_warning "No packages were created"
fi

echo ""
print_info "Installation commands:"
if [ -f "$DEB_OUTPUT" ]; then
    REL_PATH=$(realpath --relative-to="$PROJECT_ROOT" "$DEB_OUTPUT")
    echo -e "  DEB: ${GREEN}sudo dpkg -i $REL_PATH${NC}"
fi
if [ -f "$RPM_OUTPUT" ]; then
    REL_PATH=$(realpath --relative-to="$PROJECT_ROOT" "$RPM_OUTPUT")
    echo -e "  RPM: ${GREEN}sudo rpm -i $REL_PATH${NC}"
fi
if [ -f "$APPIMAGE_OUTPUT" ]; then
    REL_PATH=$(realpath --relative-to="$PROJECT_ROOT" "$APPIMAGE_OUTPUT")
    echo -e "  AppImage (System Python): ${GREEN}./$REL_PATH${NC}"
fi
if [ -f "$SELF_CONTAINED_OUTPUT" ]; then
    REL_PATH=$(realpath --relative-to="$PROJECT_ROOT" "$SELF_CONTAINED_OUTPUT")
    echo -e "  AppImage (Self-contained): ${GREEN}./$REL_PATH${NC}"
fi
if [ -f "$MACOS_OUTPUT" ]; then
    REL_PATH=$(realpath --relative-to="$PROJECT_ROOT" "$MACOS_OUTPUT")
    echo -e "  macOS App: ${GREEN}open $REL_PATH${NC}"
fi
if [ -f "$DMG_OUTPUT" ]; then
    REL_PATH=$(realpath --relative-to="$PROJECT_ROOT" "$DMG_OUTPUT")
    echo -e "  macOS DMG: ${GREEN}open $REL_PATH${NC}"
fi
echo ""
