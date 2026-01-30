@echo off
REM MiniTools Build Script for Windows
REM Build Windows EXE package

setlocal enabledelayedexpansion

echo ========================================
echo MiniTools Build Script for Windows
echo ========================================
echo.

REM Get script directory (absolute path)
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR:~0,-1%"

echo [INFO] Script directory: %SCRIPT_DIR%
echo [INFO] Project root: %PROJECT_ROOT%

REM Application metadata
set "APP_NAME=MiniTools"
set "APP_PKG_NAME=minitools"
set "APP_PYTHON_SCRIPT=MiniTools.py"
set "APP_ICON=minitools.png"

REM Extract version from Python script
for /f "tokens=2 delims==" %%V in ('type "%APP_SCRIPT_PATH%" ^| findstr /C:"__version__"') do set "VERSION=%%~V"
if "%VERSION%"=="" (
    echo [WARNING] Failed to extract version from script, using default
    set "VERSION=1.0.0"
)
echo [INFO] Detected version: %VERSION%

REM Build directory
set "BUILD_DIR=%PROJECT_ROOT%\build"

REM Dist directory for final packages
set "DIST_DIR=%PROJECT_ROOT%\dist"

REM Path definitions
set "APP_SCRIPT_PATH=%PROJECT_ROOT%\%APP_PYTHON_SCRIPT%"
set "APP_ICON_PATH=%PROJECT_ROOT%\%APP_ICON%"

REM Architecture detection
set "ARCH=%PROCESSOR_ARCHITECTURE%"
if "%ARCH%"=="AMD64" (
    set "ARCH_SUFFIX=amd64"
) else if "%ARCH%"=="ARM64" (
    set "ARCH_SUFFIX=aarch64"
) else (
    set "ARCH_SUFFIX=%ARCH%"
)

REM Architecture detection
set "ARCH=%PROCESSOR_ARCHITECTURE%"
if "%ARCH%"=="AMD64" (
    set "ARCH_SUFFIX=amd64"
) else if "%ARCH%"=="ARM64" (
    set "ARCH_SUFFIX=aarch64"
) else (
    set "ARCH_SUFFIX=%ARCH%"
)

REM Create build directory
if not exist "%BUILD_DIR%" (
    echo [INFO] Creating build directory...
    mkdir "%BUILD_DIR%"
)

if not exist "%DIST_DIR%" (
    echo [INFO] Creating dist directory...
    mkdir "%DIST_DIR%"
)

REM Check for Python
echo [INFO] Checking for Python...
where python >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found
    echo [INFO] Please install Python from https://www.python.org/downloads/
    echo [INFO] Make sure to check "Add Python to PATH" during installation
    pause
    exit /b 1
)
python --version

REM Check for PyInstaller
echo [INFO] Checking for PyInstaller...
where pyinstaller >nul 2>&1
if errorlevel 1 (
    echo [WARNING] PyInstaller not found, installing...
    python -m pip install pyinstaller
    if errorlevel 1 (
        echo [ERROR] Failed to install PyInstaller
        pause
        exit /b 1
    )
)

REM Check for PyQt6
echo [INFO] Checking for PyQt6...
python -c "import PyQt6" >nul 2>&1
if errorlevel 1 (
    echo [WARNING] PyQt6 not found, installing...
    python -m pip install PyQt6
    if errorlevel 1 (
        echo [ERROR] Failed to install PyQt6
        pause
        exit /b 1
    )
)

REM Create build directory

if not exist "%BUILD_DIR%" (

    echo [INFO] Creating build directory...

    mkdir "%BUILD_DIR%"

)



REM Check for psutil (needed for system info on Windows)
echo [INFO] Checking for psutil...
python -c "import psutil" >nul 2>&1
if errorlevel 1 (
    echo [WARNING] psutil not found, installing...
    python -m pip install psutil
    if errorlevel 1 (
        echo [ERROR] Failed to install psutil
        pause
        exit /b 1
    )
)

REM Check for wmi (needed for system info on Windows)
echo [INFO] Checking for wmi...
python -c "import wmi" >nul 2>&1
if errorlevel 1 (
    echo [WARNING] wmi not found, installing...
    python -m pip install wmi
    if errorlevel 1 (
        echo [ERROR] Failed to install wmi
        pause
        exit /b 1
    )
)

REM Check for Pillow (needed for icon conversion)
echo [INFO] Checking for Pillow...
python -c "import PIL" >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Pillow not found, installing...
    python -m pip install Pillow
    if errorlevel 1 (
        echo [ERROR] Failed to install Pillow
        pause
        exit /b 1
    )
)

REM Setup paths
set "WINDOWS_OUTPUT=%DIST_DIR%\%APP_PKG_NAME%-%VERSION%-%ARCH_SUFFIX%-self-contained.exe"

REM Clean up previous build
echo [INFO] Cleaning up previous Windows build artifacts...
if exist "%BUILD_DIR%\%APP_PKG_NAME%.dist" rmdir /s /q "%BUILD_DIR%\%APP_PKG_NAME%.dist" 2>nul
if exist "%BUILD_DIR%\%APP_PKG_NAME%.spec" del "%BUILD_DIR%\%APP_PKG_NAME%.spec" 2>nul
if exist "%BUILD_DIR%\%APP_PKG_NAME%.exe" del "%BUILD_DIR%\%APP_PKG_NAME%.exe" 2>nul
if exist "%PROJECT_ROOT%\%APP_PKG_NAME%.spec" del "%PROJECT_ROOT%\%APP_PKG_NAME%.spec" 2>nul

REM Check for icon (Windows requires .ico format)

set "ICON_ARG="

set "ICON_FILE="

echo [INFO] Project root: %PROJECT_ROOT%

echo [INFO] Icon will be generated from PNG source to ensure correct dimensions

REM Build the .ico file path properly

set "ICO_PATH=%PROJECT_ROOT%\minitools.ico"

REM Always regenerate the icon to ensure correct dimensions

echo [INFO] Forcing icon regeneration for Windows compatibility

REM Always convert PNG to ICO using Pillow for Windows compatibility

if exist "%APP_ICON_PATH%" (

    echo [INFO] Source PNG exists: %APP_ICON_PATH%

    for %%F in ("%APP_ICON_PATH%") do echo [INFO] Source PNG size: %%~zF bytes

    echo [INFO] Converting PNG icon to ICO format...

    echo [INFO] Target ICO: %PROJECT_ROOT%\minitools.ico

    REM Use Pillow to convert PNG to ICO with proper sizes

    python -c "from PIL import Image; img = Image.open(r'%APP_ICON_PATH%'); sizes = [(16,16), (32,32), (48,48), (64,64), (128,128), (256,256)]; img.save(r'%PROJECT_ROOT%\minitools.ico', format='ICO', sizes=sizes, bitmap_format='png')"

    if exist "%PROJECT_ROOT%\minitools.ico" (

        set "ICON_FILE=%PROJECT_ROOT%\minitools.ico"

        echo [INFO] Generated icon: %PROJECT_ROOT%\minitools.ico

        for %%F in ("%PROJECT_ROOT%\minitools.ico") do echo [INFO] Size: %%~zF bytes

    ) else (

        echo [WARNING] ICO file was not created

    )

) else (

    echo [WARNING] PNG icon not found at: %APP_ICON_PATH%

)

if "%ICON_FILE%"=="" (

    echo [WARNING] Building without icon

) else (

    echo [INFO] Using icon argument: --icon=%ICON_FILE%

)

REM Remove any old spec files to avoid cached icon path

if exist "%PROJECT_ROOT%\%APP_PKG_NAME%.spec" del "%PROJECT_ROOT%\%APP_PKG_NAME%.spec" 2>nul

if exist "%BUILD_DIR%\%APP_PKG_NAME%.spec" del "%BUILD_DIR%\%APP_PKG_NAME%.spec" 2>nul

REM Set Windows build directory name (format: minitools-1.0.3-{arch}-windows)

set "WINDOWS_BUILD_DIR=%BUILD_DIR%\%APP_PKG_NAME%-%VERSION%-%ARCH_SUFFIX%-windows"

REM Create Windows build directory

if not exist "%WINDOWS_BUILD_DIR%" mkdir "%WINDOWS_BUILD_DIR%"

REM Build with PyInstaller

echo [INFO] Building EXE with PyInstaller...

echo.

REM Always use command line arguments for consistency
REM All Windows build files go to build/minitools-1.0.3-{arch}-windows/

if "%ICON_FILE%"=="" (

    pyinstaller --clean --onefile --name "%APP_PKG_NAME%" --distpath "%WINDOWS_BUILD_DIR%" --workpath "%WINDOWS_BUILD_DIR%\.work" --specpath "%WINDOWS_BUILD_DIR%" --windowed --hidden-import=PyQt6 --hidden-import=PyQt6.QtCore --hidden-import=PyQt6.QtGui --hidden-import=PyQt6.QtWidgets --hidden-import=psutil --hidden-import=wmi --hidden-import=PIL "%APP_SCRIPT_PATH%"

) else (

    pyinstaller --clean --onefile --name "%APP_PKG_NAME%" --distpath "%WINDOWS_BUILD_DIR%" --workpath "%WINDOWS_BUILD_DIR%\.work" --specpath "%WINDOWS_BUILD_DIR%" --icon="%ICON_FILE%" --windowed --hidden-import=PyQt6 --hidden-import=PyQt6.QtCore --hidden-import=PyQt6.QtGui --hidden-import=PyQt6.QtWidgets --hidden-import=psutil --hidden-import=wmi --hidden-import=PIL "%APP_SCRIPT_PATH%"

)

if errorlevel 1 (
    echo [ERROR] PyInstaller build failed
    pause
    exit /b 1
)

REM Check if build succeeded
if exist "%WINDOWS_BUILD_DIR%\%APP_PKG_NAME%.exe" (
    echo.
    echo [INFO] Moving EXE to build directory...
    move /Y "%WINDOWS_BUILD_DIR%\%APP_PKG_NAME%.exe" "%BUILD_DIR%\%APP_PKG_NAME%.exe" >nul
    echo [INFO] Renaming to standard format...
    move /Y "%BUILD_DIR%\%APP_PKG_NAME%.exe" "%WINDOWS_OUTPUT%" >nul
    echo [SUCCESS] Windows EXE created: %WINDOWS_OUTPUT%
) else (
    echo [ERROR] Failed to create Windows EXE
    pause
    exit /b 1
)

REM ============================================================================
REM Summary
REM ============================================================================

echo.
echo ========================================
echo Build Summary
echo ========================================
echo.
echo Package created in: %BUILD_DIR%
echo.

if exist "%WINDOWS_OUTPUT%" (
    echo Windows EXE:
    dir "%WINDOWS_OUTPUT%" | find "%APP_PKG_NAME%"
    echo.
    echo Installation:
    echo   Run the EXE file directly: %WINDOWS_OUTPUT%
) else (
    echo [WARNING] No package was created
)

echo.
pause
endlocal