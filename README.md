# Steam Deck OLED + Omarchy: Comprehensive Installation Guide

## Overview

Based on the latest 2025 information, installing Omarchy on Steam Deck OLED requires careful consideration of hardware-specific drivers and configurations. **Omarchy requires Arch Linux as its base operating system**, not Ubuntu, so the installation process needs to be adjusted accordingly.

## Key Findings

### Hardware Compatibility Issues

The Steam Deck OLED has specific hardware requirements that differ from the LCD model:

**WiFi Compatibility**: The OLED model uses a different WiFi chip (17cb:1103) that requires the Neptune kernel from Valve's Jupiter repository for proper functionality.

**Audio Drivers**: The built-in speakers, microphone, and headphone jack require specific drivers from the `steamdeck-dsp` and `alsa-ucm-conf` packages, along with the Neptune kernel.

**Bluetooth**: OLED model uses a different Bluetooth chip (17cb:1103) that also requires Neptune kernel support.

**Display Orientation**: The built-in display may need specific configuration to prevent rotation issues.

## Installation Process

### Phase 1: Arch Linux Installation (Not Ubuntu)

Since Omarchy is specifically designed for Arch Linux, you cannot install it on Ubuntu. The correct process is:

1. **Install Arch Linux** following the Omarchy manual guidelines:
    - Use `archinstall` with btrfs filesystem
    - Enable LUKS disk encryption (required for Omarchy)
    - Install with pipewire audio system
    - Add `wget` package during installation

2. **Install Omarchy** after Arch setup:

```bash
wget -qO- https://omarchy.org/install | bash
```

### Phase 2: Steam Deck OLED Specific Fixes

The major issue is that **Omarchy's default installation doesn't include Steam Deck OLED specific drivers**. Based on the repository analysis, Omarchy focuses on general Arch/Hyprland setup without hardware-specific patches.

## Post-Installation Steam Deck OLED Fix Script

We've created a comprehensive script that addresses all Steam Deck OLED specific issues:

### Key Features of the Fix Script

1. **WiFi Fix**: Installs Neptune kernel and firmware for OLED WiFi chip compatibility
2. **Audio Fix**: Configures steamdeck-dsp and alsa-ucm-conf packages
3. **Bluetooth Fix**: Ensures proper Bluetooth driver installation
4. **Display Orientation**: Creates proper monitor configuration for built-in display
5. **Power Management**: Configures power profiles optimized for Steam Deck
6. **Steam Integration**: Installs Steam and gaming optimizations
7. **Fan Control**: Sets up proper fan control daemon

### Usage

1. **Clone this repository**:

```bash
git clone https://github.com/your-username/deckarchy.git
cd deckarchy
```

2. **Make the script executable**:

```bash
chmod +x steam-deck-oled-fix.sh
```

3. **Run the script**:

```bash
./steam-deck-oled-fix.sh
```

### Script Components

The script implements key fixes including:

- Adding Valve Jupiter repository for Steam Deck packages
- Installing linux-neptune kernel and firmware
- Configuring audio with steamdeck-dsp and alsa-ucm-conf
- Setting up proper display orientation (eDP-1,1280x800@90)
- Enabling power management and fan control
- Installing Steam and gaming optimizations
- Creating Steam Deck specific shortcuts

## Critical Display Orientation Fix

The script specifically addresses the display orientation issue by creating a proper `monitors.conf` file:

```bash
# Steam Deck OLED built-in display configuration
monitor=eDP-1,1280x800@90,0x0,1
```

This ensures the built-in display works correctly without rotation issues.

## Hardware-Specific Considerations

### WiFi Requirements

The OLED model's WiFi chip requires specific patches that are not in upstream Linux kernels. The Neptune kernel from Valve's repository is essential.

### Audio Configuration

Audio support requires multiple components working together:

- Neptune kernel for hardware support
- steamdeck-dsp for audio processing
- alsa-ucm-conf for proper audio routing
- pipewire for audio server

### Power Management

The script configures power-profiles-daemon specifically for Steam Deck's battery optimization, setting balanced mode for portable use.

## Limitations and Considerations

1. **Warranty Impact**: This completely replaces SteamOS, voiding warranty
2. **SteamOS Features Lost**: Game Mode, SteamOS-specific optimizations are not available
3. **Manual Updates**: All system updates must be managed manually
4. **Battery Life**: May differ from SteamOS optimization
5. **Game Compatibility**: Some games may require additional configuration

## Repository Analysis

The Omarchy repository shows it's designed as a general Arch/Hyprland setup without hardware-specific considerations. The main configuration files are in `/config/hypr/` and `/default/hypr/`, but they don't include Steam Deck specific settings.

## Conclusion

While Omarchy provides an excellent Arch/Hyprland setup, it requires significant additional configuration for Steam Deck OLED compatibility. The comprehensive fix script we've created addresses all major hardware issues, but users should be aware this is a complex setup that replaces the entire operating system.

The script ensures proper functionality of:

- WiFi and Bluetooth connectivity
- Audio output and input
- Display orientation
- Power management
- Gaming optimizations
- Steam Deck controls

For users wanting a Linux development environment on Steam Deck OLED, this setup provides a powerful, customizable platform, but with the trade-off of losing SteamOS's gaming-optimized features.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This script modifies your Steam Deck's operating system. Use at your own risk. The authors are not responsible for any damage to your device. Always backup your data before proceeding.
