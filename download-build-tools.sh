#!/bin/bash

# MiniTools Build Tools Download Script
# This script downloads all required tools for building MiniTools packages

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}  MiniTools Build Tools Download${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# PROJECT_ROOT is the directory containing build.sh and MiniTools.py
PROJECT_ROOT="$SCRIPT_DIR"

# All downloads go to build directory (relative to project root)
BUILD_DIR="${PROJECT_ROOT}/build"

# Verify we're in a valid project directory
if [ ! -f "${PROJECT_ROOT}/MiniTools.py" ]; then
    echo -e "${RED}✗ Error: MiniTools.py not found in project root${NC}"
    echo -e "${YELLOW}  Please run this script from the project root directory${NC}"
    exit 1
fi

# Create build directory
mkdir -p "${BUILD_DIR}"

# Track downloaded files
DOWNLOADED_FILES=()

echo -e "${BLUE}Downloading build tools to: ${BUILD_DIR}${NC}"
echo ""

# Download appimagetool
echo -e "${YELLOW}[1/1] Downloading appimagetool...${NC}"
APPIMAGETOOL_FILE="${BUILD_DIR}/appimagetool-x86_64.AppImage"
if [ -f "$APPIMAGETOOL_FILE" ]; then
    echo -e "${GREEN}✓ appimagetool already exists, skipping${NC}"
    DOWNLOADED_FILES+=("$APPIMAGETOOL_FILE")
else
    wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O "$APPIMAGETOOL_FILE"
    chmod +x "$APPIMAGETOOL_FILE"
    echo -e "${GREEN}✓ appimagetool downloaded${NC}"
    DOWNLOADED_FILES+=("$APPIMAGETOOL_FILE")
fi
echo ""

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  Download completed!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""

# Only show files downloaded by this script
echo -e "${BLUE}Files downloaded:${NC}"
for file in "${DOWNLOADED_FILES[@]}"; do
    if [ -f "$file" ]; then
        ls -lh "$file"
    fi
done
echo ""

echo -e "${BLUE}You can now run: ./build.sh${NC}"
echo ""
echo -e "${YELLOW}Note: For self-contained AppImage builds, PyInstaller will be used${NC}"
echo -e "${YELLOW}      to bundle the application with Python and PyQt6.${NC}"