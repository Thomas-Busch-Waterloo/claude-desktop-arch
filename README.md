# Claude Desktop for Linux

***THIS IS AN UNOFFICIAL BUILD SCRIPT!***

If you run into an issue with this build script, make an issue here. Don't bug Anthropic about it - they already have enough on their plates.

This project was inspired by [k3d3's claude-desktop-linux-flake](https://github.com/k3d3/claude-desktop-linux-flake) and their [Reddit post](https://www.reddit.com/r/ClaudeAI/comments/1hgsmpq/i_successfully_ran_claude_desktop_natively_on/) about running Claude Desktop natively on Linux. Their work provided valuable insights into the application's structure and the native bindings implementation.

Claude Desktop now supports multiple Linux distributions including Debian-based systems (Ubuntu, Linux Mint, MX Linux), NixOS, and Arch-based systems (Arch Linux, Manjaro, cachyOS).

## Features

- Supports MCP! Location of the MCP-configuration file is: `~/.config/Claude/claude_desktop_config.json`
- Supports the Ctrl+Alt+Space popup!
- Supports the Tray menu!

![image](https://github.com/user-attachments/assets/93080028-6f71-48bd-8e59-5149d148cd45)

# Installation Options

## 1. Arch Linux Installation (New!)

For Arch Linux-based distributions (Arch Linux, Manjaro, cachyOS, etc.), you can build and install Claude Desktop using the provided Arch build script:

```bash
# Clone this repository
git clone https://github.com/Thomas-Busch-Waterloo/claude-desktop-arch.git
cd claude-desktop-arch

# Build and install
sudo ./build-arch.sh

# Follow the instructions to install using one of the provided methods:
# Option 1: Use makepkg to create and install an Arch package
cd build
makepkg -si

# OR

# Option 2: Use the direct installation script (simpler)
sudo ./build/install.sh
```

Requirements:
- Any Arch Linux-based distribution
- Node.js and npm
- electron package
- Root/sudo access for dependency installation

The script automatically:
- Checks for and installs required dependencies via pacman
- Downloads and extracts resources from the Windows version
- Handles localization files for proper Electron integration
- Provides both package-based and direct installation options

## 2. Debian Package

For Debian-based distributions (Debian, Ubuntu, Linux Mint, MX Linux, etc.), please refer to [aaddrick's claude-desktop-debian](https://github.com/aaddrick/claude-desktop-debian) repository. Their implementation is specifically designed for NixOS and provides the original Nix flake that inspired this project.

## 3. NixOS Implementation

For NixOS users, please refer to [k3d3's claude-desktop-linux-flake](https://github.com/aaddrick/claude-desktop-debian/tree/main) repository. Their implementation is specifically designed for NixOS and provides the original Nix flake that inspired this project.

# How it works

Claude Desktop is an Electron application packaged as a Windows executable. Our build script performs several key operations to make it work on Linux:

1. Downloads and extracts the Windows installer
2. Unpacks the app.asar archive containing the application code
3. Replaces the Windows-specific native module with a Linux-compatible implementation
4. Repackages everything into the appropriate format for your distribution

The process works because Claude Desktop is largely cross-platform, with only one platform-specific component that needs replacement.

## The Native Module Challenge

The only platform-specific component is a native Node.js module called `claude-native-bindings`. This module provides system-level functionality like:

- Keyboard input handling
- Window management
- System tray integration
- Monitor information

Our build script replaces this Windows-specific module with a Linux-compatible implementation that:

1. Provides the same API surface to maintain compatibility
2. Implements keyboard handling using the correct key codes from the reference implementation
3. Stubs out unnecessary Windows-specific functionality
4. Maintains critical features like the Ctrl+Alt+Space popup and system tray

The replacement module is carefully designed to match the original API while providing Linux-native functionality where needed. This approach allows the rest of the application to run unmodified, believing it's still running on Windows.

## Build Process Details

> Note: The build scripts were generated by Claude (Anthropic) to help create Linux-compatible versions of Claude Desktop.

The build scripts handle the entire process:

1. Check for system requirements and install dependencies
2. Download the official Windows installer
3. Extract the application resources
4. Process icons for Linux desktop integration
5. Unpack and modify the app.asar:
   - Replace the native module with our Linux version
   - Update keyboard key mappings
   - Handle localization files properly
   - Preserve all other functionality
6. Create installation packages with:
   - Desktop entry for application menus
   - System-wide icon integration
   - Proper dependency management
   - Post-install configuration

## Updating the Build Script

When a new version of Claude Desktop is released, simply update the `CLAUDE_DOWNLOAD_URL` constant at the top of the build script to point to the new installer. The script will handle everything else automatically, including detecting the correct version number from the files.

# License

The build scripts in this repository are dual-licensed under the terms of the MIT license and the Apache License (Version 2.0).

See [LICENSE-MIT](LICENSE-MIT) and [LICENSE-APACHE](LICENSE-APACHE) for details.

The Claude Desktop application, not included in this repository, is likely covered by [Anthropic's Consumer Terms](https://www.anthropic.com/legal/consumer-terms).

## Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
