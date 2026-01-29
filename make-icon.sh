#!/bin/bash
# MiniTools Icon Generator
# Generate icons from SVG source

set -e

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
SVG_ICON="$PROJECT_ROOT/minitools.svg"
APP_NAME="minitools"

# Icon sizes (from small to large)
ICON_SIZES=(16 32 48 64 128 256 512 1024)

# macOS iconset mappings: target_size -> (source_size, filename)
declare -A MACOS_ICONSET=(
    ["icon_16x16.png"]="16"
    ["icon_16x16@2x.png"]="32"
    ["icon_32x32.png"]="32"
    ["icon_32x32@2x.png"]="64"
    ["icon_128x128.png"]="128"
    ["icon_128x128@2x.png"]="256"
    ["icon_256x256.png"]="256"
    ["icon_256x256@2x.png"]="512"
    ["icon_512x512.png"]="512"
    ["icon_512x512@2x.png"]="1024"
)

# Windows ICO sizes (subset of ICON_SIZES)
ICO_SIZES=(16 32 48 64 128 256)

# WebP sizes (exclude 1024 as it's less common)
WEBP_SIZES=(16 32 48 64 128 256 512)

# Default standard PNG size
STANDARD_PNG_SIZE=256

# ============================================================================
# Color and Output Functions
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
    echo ""
}

# ============================================================================
# Helper Functions
# ============================================================================

# Get ImageMagick command
get_convert_cmd() {
    if command -v magick &> /dev/null; then
        echo "magick"
    elif command -v convert &> /dev/null; then
        echo "convert"
    else
        return 1
    fi
}

# Generate PNG file path for a given size
get_png_path() {
    local size=$1
    echo "${PROJECT_ROOT}/${APP_NAME}-${size}x${size}.png"
}

# Check if required PNG exists
check_png_exists() {
    local size=$1
    local png_path=$(get_png_path "$size")
    
    if [ ! -f "$png_path" ]; then
        print_error "Required PNG not found: $png_path"
        print_error "Please run generate_png() first"
        return 1
    fi
    
    return 0
}

# ============================================================================
# Dependency Checking
# ============================================================================

check_dependencies() {
    print_header "Checking Dependencies" >&2
    
    # Check for ImageMagick
    local convert_cmd
    convert_cmd=$(get_convert_cmd)
    
    if [ $? -ne 0 ]; then
        print_error "ImageMagick not found (magick or convert)" >&2
        echo "" >&2
        print_info "Install ImageMagick with:" >&2
        echo "  Ubuntu/Debian: sudo apt install imagemagick" >&2
        echo "  Fedora: sudo dnf install ImageMagick" >&2
        echo "  Arch: sudo pacman -S imagemagick" >&2
        exit 1
    fi
    
    # Output to stderr so it doesn't interfere with command capture
    print_success "ImageMagick found: $convert_cmd" >&2
    
    # Return the command to stdout
    echo "$convert_cmd"
}

# ============================================================================
# Icon Generation Functions
# ============================================================================

# Generate PNG icons in all required sizes
generate_png() {
    print_header "Generating PNG Icons"
    
    local convert_cmd=$1
    local generated_count=0
    
    for size in "${ICON_SIZES[@]}"; do
        local output_path=$(get_png_path "$size")
        
        print_info "Generating ${size}x${size}..."
        
        if $convert_cmd "$SVG_ICON" -resize "${size}x${size}" "$output_path"; then
            print_success "Generated: $output_path"
            generated_count=$((generated_count + 1))
        else
            print_error "Failed to generate: $output_path"
        fi
    done
    
    # Create standard PNG (256x256 by default)
    local standard_path="${PROJECT_ROOT}/${APP_NAME}.png"
    local standard_png=$(get_png_path "$STANDARD_PNG_SIZE")
    
    if [ -f "$standard_png" ]; then
        cp "$standard_png" "$standard_path"
        print_success "Created standard PNG: $standard_path (${STANDARD_PNG_SIZE}x${STANDARD_PNG_SIZE})"
    else
        print_warning "Standard PNG source not found: $standard_png"
    fi
    
    echo ""
    print_info "Generated $generated_count PNG icons"
}

# Generate Windows ICO file
generate_ico() {
    print_header "Generating Windows ICO"
    
    local convert_cmd=$1
    local ico_output="${PROJECT_ROOT}/${APP_NAME}.ico"
    local png_files=()
    
    # Collect PNG files for ICO
    for size in "${ICO_SIZES[@]}"; do
        if check_png_exists "$size"; then
            png_files+=("$(get_png_path "$size")")
        fi
    done
    
    if [ ${#png_files[@]} -eq 0 ]; then
        print_error "No PNG files found for ICO generation"
        return 1
    fi
    
    print_info "Creating ICO from ${#png_files[@]} sizes..."
    
    if $convert_cmd "${png_files[@]}" "$ico_output" 2>/dev/null; then
        print_success "Created: $ico_output"
    else
        print_error "Failed to create: $ico_output"
        return 1
    fi
}

# Generate macOS ICNS file
generate_icns() {
    print_header "Generating macOS ICNS"
    
    local convert_cmd=$1
    local icns_output="${PROJECT_ROOT}/${APP_NAME}.icns"
    local iconset_dir="${PROJECT_ROOT}/${APP_NAME}.iconset"
    
    # Check platform
    if [ "$(uname)" != "Darwin" ]; then
        print_warning "Not running on macOS"
        print_warning "ICNS generation will be limited"
        echo ""
    fi
    
    # Create iconset directory
    rm -rf "$iconset_dir"
    mkdir -p "$iconset_dir"
    
    # Copy PNG files to iconset with macOS naming convention
    for target_file in "${!MACOS_ICONSET[@]}"; do
        local source_size="${MACOS_ICONSET[$target_file]}"
        
        if check_png_exists "$source_size"; then
            local source_path=$(get_png_path "$source_size")
            cp "$source_path" "${iconset_dir}/${target_file}"
        fi
    done
    
    # Generate ICNS
    if command -v iconutil &> /dev/null; then
        print_info "Using iconutil (macOS native tool)..."
        
        if iconutil -c icns "$iconset_dir" -o "$icns_output" 2>/dev/null; then
            rm -rf "$iconset_dir"
            print_success "Created: $icns_output (proper macOS format)"
        else
            print_error "iconutil failed"
            return 1
        fi
    else
        print_warning "iconutil not found, using ImageMagick fallback"
        print_warning "Result may have limited macOS compatibility"
        echo ""
        
        # Use ImageMagick fallback (single size)
        local fallback_size=1024
        if check_png_exists "$fallback_size"; then
            local fallback_png=$(get_png_path "$fallback_size")
            
            if $convert_cmd "$fallback_png" "$icns_output" 2>/dev/null; then
                print_warning "Created: $icns_output (ImageMagick fallback)"
                print_warning "For production, regenerate on macOS with iconutil"
                rm -rf "$iconset_dir"
            else
                print_error "ImageMagick fallback failed"
                print_info "Iconset directory preserved at: $iconset_dir"
                return 1
            fi
        fi
    fi
}

# Generate WebP icons (optional)
generate_webp() {
    print_header "Generating WebP Icons"
    
    if ! command -v cwebp &> /dev/null; then
        print_info "cwebp not found, skipping WebP generation"
        return
    fi
    
    local generated_count=0
    
    for size in "${WEBP_SIZES[@]}"; do
        local png_path=$(get_png_path "$size")
        local webp_path="${png_path%.png}.webp"
        
        if [ -f "$png_path" ]; then
            print_info "Converting ${size}x${size} to WebP..."
            
            if cwebp -q 90 "$png_path" -o "$webp_path" -quiet 2>/dev/null; then
                print_success "Generated: $webp_path"
                generated_count=$((generated_count + 1))
            fi
        fi
    done
    
    echo ""
    print_info "Generated $generated_count WebP icons"
}

# Cleanup intermediate files
cleanup_intermediate() {
    print_header "Cleaning Up Intermediate Files"
    
    local removed_count=0
    
    # Remove sized PNG files (except standard PNG)
    for size in "${ICON_SIZES[@]}"; do
        local file_path=$(get_png_path "$size")
        if [ -f "$file_path" ]; then
            rm "$file_path"
            print_success "Removed: $file_path"
            removed_count=$((removed_count + 1))
        fi
    done
    
    # Remove WebP files
    for size in "${WEBP_SIZES[@]}"; do
        local png_path=$(get_png_path "$size")
        local webp_path="${png_path%.png}.webp"
        
        if [ -f "$webp_path" ]; then
            rm "$webp_path"
            print_success "Removed: $webp_path"
            removed_count=$((removed_count + 1))
        fi
    done
    
    # Remove iconset directory if it exists
    local iconset_dir="${PROJECT_ROOT}/${APP_NAME}.iconset"
    if [ -d "$iconset_dir" ]; then
        rm -rf "$iconset_dir"
        print_success "Removed: $iconset_dir"
        removed_count=$((removed_count + 1))
    fi
    
    echo ""
    print_success "Cleanup complete: Removed $removed_count files/directories"
}

# ============================================================================
# Main Function
# ============================================================================

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate icons from SVG source for multiple platforms.

OPTIONS:
    --cleanup        Clean up intermediate files after generation (default)
    --no-cleanup     Keep intermediate files for debugging
    --skip-webp      Skip WebP generation
    -h, --help       Show this help message

OUTPUT FILES:
    minitools.png    Standard PNG (256x256)
    minitools.ico    Windows icon (multiple sizes)
    minitools.icns   macOS icon (multiple sizes)
    minitools*.webp  WebP icons (optional)

DEPENDENCIES:
    - ImageMagick (magick or convert)
    - iconutil (macOS-only, recommended for ICNS)
    - cwebp (optional, for WebP generation)

EOF
}

main() {
    print_header "MiniTools Icon Generator"
    
    # Check if SVG exists
    if [ ! -f "$SVG_ICON" ]; then
        print_error "SVG icon not found: $SVG_ICON"
        exit 1
    fi
    
    print_info "Source: $SVG_ICON"
    print_info "Output: $PROJECT_ROOT"
    echo ""
    
    # Parse arguments
    CLEANUP=true
    SKIP_WEBP=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cleanup)
                CLEANUP=true
                shift
                ;;
            --no-cleanup)
                CLEANUP=false
                shift
                ;;
            --skip-webp)
                SKIP_WEBP=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo ""
                usage
                exit 1
                ;;
        esac
    done
    
    # Check dependencies and get convert command
    local convert_cmd
    convert_cmd=$(check_dependencies)
    
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    # Generate icons
    generate_png "$convert_cmd"
    generate_ico "$convert_cmd"
    generate_icns "$convert_cmd"
    
    if [ "$SKIP_WEBP" = false ]; then
        generate_webp
    fi
    
    # Clean up intermediate files
    if [ "$CLEANUP" = true ]; then
        cleanup_intermediate
    fi
    
    # Summary
    print_header "Summary"
    print_success "Icon generation complete!"
    echo ""
    print_info "Final icon files:"
    
    # List final icon files
    for ext in png icns ico; do
        for file in "$PROJECT_ROOT"/${APP_NAME}*.${ext}; do
            if [ -f "$file" ] && [[ "$file" != *"x${ext}" ]]; then
                ls -lh "$file" | awk '{printf "  %-40s %6s\n", $9, $5}'
            fi
        done
    done 2>/dev/null || true
    
    echo ""
    print_info "Use --no-cleanup to keep intermediate files"
}

# Run main function
main "$@"