#!/bin/bash
set -e

# Update this URL when a new version of Claude Desktop is released
CLAUDE_DOWNLOAD_URL="https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe"

# Check for Arch Linux-based system
if [ ! -f "/etc/arch-release" ] && ! grep -q "Arch Linux" /etc/os-release; then
    echo "❌ This script requires an Arch Linux-based distribution (including cachyOS)"
    exit 1
fi

# Check for root/sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo to install dependencies"
    exit 1
fi

# Print system information
echo "System Information:"
echo "Distribution: $(cat /etc/os-release | grep "PRETTY_NAME" | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "❌ $1 not found"
        return 1
    else
        echo "✓ $1 found"
        return 0
    fi
}

# Check and install dependencies
echo "Checking dependencies..."
DEPS_TO_INSTALL=""

# Check system package dependencies
for cmd in 7z wget wrestool icotool convert npm electron; do
    if ! check_command "$cmd"; then
        case "$cmd" in
            "7z")
                DEPS_TO_INSTALL="$DEPS_TO_INSTALL p7zip"
                ;;
            "wget")
                DEPS_TO_INSTALL="$DEPS_TO_INSTALL wget"
                ;;
            "wrestool"|"icotool")
                DEPS_TO_INSTALL="$DEPS_TO_INSTALL icoutils"
                ;;
            "convert")
                DEPS_TO_INSTALL="$DEPS_TO_INSTALL imagemagick"
                ;;
            "npm")
                DEPS_TO_INSTALL="$DEPS_TO_INSTALL npm"
                ;;
            "electron")
                DEPS_TO_INSTALL="$DEPS_TO_INSTALL electron"
                ;;
        esac
    fi
done

# Install system dependencies if any
if [ ! -z "$DEPS_TO_INSTALL" ]; then
    echo "Installing system dependencies: $DEPS_TO_INSTALL"
    pacman -Sy --noconfirm $DEPS_TO_INSTALL
    echo "System dependencies installed successfully"
fi

# Install asar package if needed
if ! npm list -g asar > /dev/null 2>&1; then
    echo "Installing asar package globally..."
    npm install -g asar
fi

# We'll discover the correct version from the extracted files
PACKAGE_NAME="claude-desktop"

# Create working directories
WORK_DIR="$(pwd)/build"
INSTALL_ROOT="$WORK_DIR/install"
INSTALL_DIR="$INSTALL_ROOT/opt/$PACKAGE_NAME"

# Clean previous build
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_ROOT/usr/share/applications"
mkdir -p "$INSTALL_ROOT/usr/share/icons"
mkdir -p "$INSTALL_ROOT/usr/bin"

# Download Claude Windows installer
echo "📥 Downloading Claude Desktop installer..."
CLAUDE_EXE="$WORK_DIR/Claude-Setup-x64.exe"
if ! wget -O "$CLAUDE_EXE" "$CLAUDE_DOWNLOAD_URL"; then
    echo "❌ Failed to download Claude Desktop installer"
    exit 1
fi
echo "✓ Download complete"

# Extract resources
echo "📦 Extracting resources..."
cd "$WORK_DIR"
if ! 7z x -y "$CLAUDE_EXE"; then
    echo "❌ Failed to extract installer"
    exit 1
fi

# Extract version from the extracted nupkg filename
FILES=$(ls -1 "$WORK_DIR" | grep -E "AnthropicClaude-[0-9]+\.[0-9]+\.[0-9]+-full\.nupkg")

if [ -n "$FILES" ]; then
    FILENAME=$(echo "$FILES" | head -n 1)
    VERSION=$(echo "$FILENAME" | grep -o -E "[0-9]+\.[0-9]+\.[0-9]+" | head -n 1)
    if [ -n "$VERSION" ]; then
        echo "✓ Found Version: $VERSION"
    else
        echo "❌ Failed to extract version"
        VERSION="0.8.0"  # Default fallback version
    fi
else
    echo "❌ Failed to find nupkg file"
    VERSION="0.8.0"  # Default fallback version
fi

if ! 7z x -y "AnthropicClaude-$VERSION-full.nupkg"; then
    echo "❌ Failed to extract nupkg"
    exit 1
fi
echo "✓ Resources extracted"

# Extract and convert icons
echo "🎨 Processing icons..."
if ! wrestool -x -t 14 "lib/net45/claude.exe" -o claude.ico; then
    echo "❌ Failed to extract icons from exe"
    exit 1
fi

if ! icotool -x claude.ico; then
    echo "❌ Failed to convert icons"
    exit 1
fi
echo "✓ Icons processed"

# Map icon sizes to their corresponding extracted files
declare -A icon_files=(
    ["16"]="claude_13_16x16x32.png"
    ["24"]="claude_11_24x24x32.png"
    ["32"]="claude_10_32x32x32.png"
    ["48"]="claude_8_48x48x32.png"
    ["64"]="claude_7_64x64x32.png"
    ["256"]="claude_6_256x256x32.png"
)

# Install icons
for size in 16 24 32 48 64 256; do
    icon_dir="$INSTALL_ROOT/usr/share/icons/hicolor/${size}x${size}/apps"
    mkdir -p "$icon_dir"
    if [ -f "${icon_files[$size]}" ]; then
        echo "Installing ${size}x${size} icon..."
        install -Dm 644 "${icon_files[$size]}" "$icon_dir/claude-desktop.png"
    else
        echo "Warning: Missing ${size}x${size} icon"
    fi
done

# Process app.asar
mkdir -p electron-app
cp "lib/net45/resources/app.asar" electron-app/
cp -r "lib/net45/resources/app.asar.unpacked" electron-app/

cd electron-app
npx asar extract app.asar app.asar.contents

# Replace native module with stub implementation
echo "Creating stub native module..."
cat > app.asar.contents/node_modules/claude-native/index.js << EOF
// Stub implementation of claude-native using KeyboardKey enum values
const KeyboardKey = {
  Backspace: 43,
  Tab: 280,
  Enter: 261,
  Shift: 272,
  Control: 61,
  Alt: 40,
  CapsLock: 56,
  Escape: 85,
  Space: 276,
  PageUp: 251,
  PageDown: 250,
  End: 83,
  Home: 154,
  LeftArrow: 175,
  UpArrow: 282,
  RightArrow: 262,
  DownArrow: 81,
  Delete: 79,
  Meta: 187
};

Object.freeze(KeyboardKey);

module.exports = {
  getWindowsVersion: () => "10.0.0",
  setWindowEffect: () => {},
  removeWindowEffect: () => {},
  getIsMaximized: () => false,
  flashFrame: () => {},
  clearFlashFrame: () => {},
  showNotification: () => {},
  setProgressBar: () => {},
  clearProgressBar: () => {},
  setOverlayIcon: () => {},
  clearOverlayIcon: () => {},
  KeyboardKey
};
EOF

# Copy Tray icons
mkdir -p app.asar.contents/resources
cp ../lib/net45/resources/Tray* app.asar.contents/resources/

# Copy i18n json files
mkdir -p app.asar.contents/resources/i18n
cp ../lib/net45/resources/*.json app.asar.contents/resources/i18n/

# Repackage app.asar
npx asar pack app.asar.contents app.asar

# Create native module with keyboard constants
mkdir -p "$INSTALL_DIR/app.asar.unpacked/node_modules/claude-native"
cat > "$INSTALL_DIR/app.asar.unpacked/node_modules/claude-native/index.js" << EOF
// Stub implementation of claude-native using KeyboardKey enum values
const KeyboardKey = {
  Backspace: 43,
  Tab: 280,
  Enter: 261,
  Shift: 272,
  Control: 61,
  Alt: 40,
  CapsLock: 56,
  Escape: 85,
  Space: 276,
  PageUp: 251,
  PageDown: 250,
  End: 83,
  Home: 154,
  LeftArrow: 175,
  UpArrow: 282,
  RightArrow: 262,
  DownArrow: 81,
  Delete: 79,
  Meta: 187
};

Object.freeze(KeyboardKey);

module.exports = {
  getWindowsVersion: () => "10.0.0",
  setWindowEffect: () => {},
  removeWindowEffect: () => {},
  getIsMaximized: () => false,
  flashFrame: () => {},
  clearFlashFrame: () => {},
  showNotification: () => {},
  setProgressBar: () => {},
  clearProgressBar: () => {},
  setOverlayIcon: () => {},
  clearOverlayIcon: () => {},
  KeyboardKey
};
EOF

# Copy app files
cp app.asar "$INSTALL_DIR/"
cp -r app.asar.unpacked "$INSTALL_DIR/"

# Create desktop entry
cat > "$INSTALL_ROOT/usr/share/applications/claude-desktop.desktop" << EOF
[Desktop Entry]
Name=Claude
Exec=claude-desktop %u
Icon=claude-desktop
Type=Application
Terminal=false
Categories=Office;Utility;
MimeType=x-scheme-handler/claude;
StartupWMClass=Claude
EOF

# Create launcher script
cat > "$INSTALL_ROOT/usr/bin/claude-desktop" << EOF
#!/bin/bash

# Handle missing localization files by setting an environment variable to override
# the default location if needed
export ELECTRON_OVERRIDE_DIST_PATH=/opt/claude-desktop

# Run Claude Desktop
electron /opt/claude-desktop/app.asar "\$@"
EOF
chmod +x "$INSTALL_ROOT/usr/bin/claude-desktop"

# Create PKGBUILD file for Arch Linux
cat > "$WORK_DIR/PKGBUILD" << EOF
# Maintainer: Claude Desktop Linux Maintainers

pkgname=claude-desktop
pkgver=$VERSION
pkgrel=1
pkgdesc="Claude AI Assistant Desktop Application"
arch=('x86_64')
url="https://www.anthropic.com/claude"
license=('custom')
depends=('electron' 'nodejs' 'npm')
provides=('claude-desktop')
conflicts=('claude-desktop')

package() {
  cp -r "$INSTALL_ROOT"/* "\$pkgdir/"
}
EOF

# Optionally, create a makepkg script
cat > "$WORK_DIR/build-package.sh" << EOF
#!/bin/bash
cd "\$(dirname "\$0")"
makepkg -si
EOF
chmod +x "$WORK_DIR/build-package.sh"

# Manual installation option
echo "Creating direct installation script..."
cat > "$WORK_DIR/install.sh" << EOF
#!/bin/bash
set -e

# Check for root
if [ "\$EUID" -ne 0 ]; then
    echo "Please run with sudo to install"
    exit 1
fi

# Copy files to system directories
echo "Installing Claude Desktop files..."
cp -r "$INSTALL_ROOT/opt" /
cp -r "$INSTALL_ROOT/usr" /

# Set permissions
chmod +x /usr/bin/claude-desktop
chmod +x /opt/claude-desktop/app.asar

# Fix for missing Electron localization files
BUILD_I18N_DIR="$WORK_DIR/electron-app/app.asar.contents/resources/i18n"
ELECTRON_PATH=\$(which electron)

if [ -z "\$ELECTRON_PATH" ]; then
    echo "Warning: Electron not found in PATH. Trying to find it manually..."
    ELECTRON_PATH=\$(find /usr/bin -name "electron*" | head -n 1)
fi

if [ -n "\$ELECTRON_PATH" ]; then
    echo "Found Electron at: \$ELECTRON_PATH"
    # Try to get Electron version to find the resources dir
    ELECTRON_VERSION=\$(\$ELECTRON_PATH --version 2>/dev/null | cut -d 'v' -f2 || echo "")
    MAJOR_VERSION=\$(echo \$ELECTRON_VERSION | cut -d '.' -f1 || echo "")

    # Check various possible resource locations
    POSSIBLE_DIRS=(
        "/usr/lib/electron\$MAJOR_VERSION/resources"
        "/usr/lib/electron/resources"
        "/usr/share/electron/resources"
        "/usr/lib/electron\$MAJOR_VERSION"
        "/usr/share/electron\$MAJOR_VERSION/resources"
    )

    # Find the first valid directory
    ELECTRON_RESOURCES_DIR=""
    for dir in "\${POSSIBLE_DIRS[@]}"; do
        if [ -d "\$dir" ]; then
            ELECTRON_RESOURCES_DIR="\$dir"
            if [ ! -d "\$ELECTRON_RESOURCES_DIR/resources" ] && [[ "\$ELECTRON_RESOURCES_DIR" != */resources ]]; then
                ELECTRON_RESOURCES_DIR="\$ELECTRON_RESOURCES_DIR/resources"
            fi
            echo "Found Electron resources directory: \$ELECTRON_RESOURCES_DIR"
            break
        fi
    done

    # If still not found, try to find with locate or manual search
    if [ -z "\$ELECTRON_RESOURCES_DIR" ]; then
        echo "Searching for Electron resources directory..."
        ELECTRON_RESOURCES_DIR=\$(find /usr/lib -name "electron*" -type d 2>/dev/null | grep -v "node_modules" | head -n 1)
        if [ -n "\$ELECTRON_RESOURCES_DIR" ]; then
            if [ ! -d "\$ELECTRON_RESOURCES_DIR/resources" ]; then
                ELECTRON_RESOURCES_DIR="\$ELECTRON_RESOURCES_DIR/resources"
            fi
            echo "Found Electron resources directory: \$ELECTRON_RESOURCES_DIR"
        fi
    fi
else
    echo "Warning: Electron not found. Claude might not start properly."
fi

# Use both the build i18n directory and the installed one
if [ -d "\$BUILD_I18N_DIR" ] && [ -n "\$ELECTRON_RESOURCES_DIR" ] && [ -d "\$ELECTRON_RESOURCES_DIR" ]; then
    echo "Copying localization files from build directory..."
    mkdir -p "\$ELECTRON_RESOURCES_DIR"
    cp "\$BUILD_I18N_DIR"/*.json "\$ELECTRON_RESOURCES_DIR/"
    echo "✓ Localization files copied successfully"
else
    echo "Warning: Could not copy localization files from build directory."
    echo "  - Build i18n directory: \$BUILD_I18N_DIR"
    echo "  - Electron resources directory: \$ELECTRON_RESOURCES_DIR"

    # Alternative approach - try to copy from the original build location
    echo "Trying alternative approach..."
    ALTERNATE_I18N_DIR="$WORK_DIR/lib/net45/resources"
    if [ -d "\$ALTERNATE_I18N_DIR" ] && [ -n "\$ELECTRON_RESOURCES_DIR" ]; then
        echo "Copying localization files from alternate location..."
        find "\$ALTERNATE_I18N_DIR" -name "*.json" -exec cp {} "\$ELECTRON_RESOURCES_DIR/" \;
        echo "✓ Alternate copy completed"
    else
        echo "Alternative approach failed. You may need to manually copy the i18n files."
        echo "Try: sudo cp \"$WORK_DIR/electron-app/app.asar.contents/resources/i18n/\"*.json \$ELECTRON_RESOURCES_DIR/"
    fi
fi

echo "✓ Claude Desktop installed successfully!"
echo "You can now launch Claude by running 'claude-desktop' or from your application menu."
EOF
chmod +x "$WORK_DIR/install.sh"

echo "✓ Build completed successfully!"
echo
echo "You have two installation options:"
echo
echo "1. Use makepkg to create and install an Arch package:"
echo "   cd $WORK_DIR"
echo "   makepkg -si"
echo
echo "2. Use the direct installation script (simpler):"
echo "   sudo $WORK_DIR/install.sh"
echo
echo "The direct installation is recommended for most users."
echo "Note: You may need to update your desktop database after installation:"
echo "   update-desktop-database"
