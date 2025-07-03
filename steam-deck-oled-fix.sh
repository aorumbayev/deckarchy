#!/bin/bash

# Steam Deck OLED Post-Omarchy Installation Script
# This script fixes Steam Deck OLED specific issues after Omarchy installation

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Steam Deck OLED Post-Omarchy Fix Script${NC}"
echo -e "${BLUE}========================================${NC}"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Steam Deck
check_steam_deck() {
    print_status "Checking if running on Steam Deck..."
    if [[ $(dmidecode -s system-product-name 2>/dev/null) == *"Steam Deck"* ]] || [[ -f /sys/class/dmi/id/product_name && $(cat /sys/class/dmi/id/product_name) == *"Steam Deck"* ]]; then
        print_status "Steam Deck detected"
        return 0
    else
        print_warning "This script is designed for Steam Deck. Proceeding anyway..."
        return 1
    fi
}

# Install essential packages for Steam Deck
install_steam_deck_packages() {
    print_status "Installing Steam Deck specific packages..."

    # Add Valve's Jupiter repository for Steam Deck specific packages
    if ! grep -q "jupiter" /etc/pacman.conf; then
        print_status "Adding Valve Jupiter repository..."
        sudo tee -a /etc/pacman.conf > /dev/null <<EOF

[jupiter]
SigLevel = Optional TrustAll
Server = https://steamdeck-packages.steamos.cloud/archlinux-mirror/jupiter-main/os/x86_64/
EOF
    fi

    # Update package database
    sudo pacman -Sy

    # Install Steam Deck specific kernel and firmware
    print_status "Installing Steam Deck kernel and firmware..."
    yay -S --noconfirm linux-neptune linux-neptune-headers
    yay -S --noconfirm linux-firmware-neptune

    # Install Steam Deck specific packages
    print_status "Installing additional Steam Deck packages..."
    yay -S --noconfirm steamdeck-dsp alsa-ucm-conf

    # Install gamepad drivers and Steam controller support
    yay -S --noconfirm steam-devices
}

# Fix WiFi for Steam Deck OLED
fix_wifi() {
    print_status "Fixing WiFi for Steam Deck OLED..."

    # Check if this is OLED model
    if lspci | grep -q "17cb:1103"; then
        print_status "Steam Deck OLED WiFi chip detected"

        # Install neptune kernel if not already installed
        if ! pacman -Qs linux-neptune > /dev/null; then
            print_status "Installing Neptune kernel for WiFi support..."
            yay -S --noconfirm linux-neptune linux-neptune-headers
        fi

        # Install firmware
        yay -S --noconfirm linux-firmware-neptune

        print_status "WiFi fix applied. Reboot required for changes to take effect."
    else
        print_status "Non-OLED Steam Deck detected, standard WiFi drivers should work"
    fi
}

# Fix Bluetooth for Steam Deck OLED
fix_bluetooth() {
    print_status "Fixing Bluetooth for Steam Deck OLED..."

    # Enable and start bluetooth service
    sudo systemctl enable bluetooth
    sudo systemctl start bluetooth

    # Install bluetooth packages
    yay -S --noconfirm bluez bluez-utils

    print_status "Bluetooth service enabled and started"
}

# Fix audio for Steam Deck OLED
fix_audio() {
    print_status "Fixing audio for Steam Deck OLED..."

    # Install audio packages
    yay -S --noconfirm pipewire pipewire-alsa pipewire-pulse wireplumber
    yay -S --noconfirm steamdeck-dsp alsa-ucm-conf

    # Enable audio services
    systemctl --user enable pipewire
    systemctl --user enable wireplumber
    systemctl --user start pipewire
    systemctl --user start wireplumber

    print_status "Audio services configured"
}

# Fix display orientation for built-in screen
fix_display_orientation() {
    print_status "Fixing display orientation for Steam Deck built-in screen..."

    # Create monitor configuration for Steam Deck
    mkdir -p ~/.config/hypr

    # Check if monitors.conf exists and backup if it does
    if [[ -f ~/.config/hypr/monitors.conf ]]; then
        cp ~/.config/hypr/monitors.conf ~/.config/hypr/monitors.conf.backup
        print_status "Backed up existing monitors.conf"
    fi

    # Create Steam Deck specific monitor configuration
    cat > ~/.config/hypr/monitors.conf << 'EOF'
# Steam Deck OLED built-in display configuration
# The built-in display is eDP-1 and needs proper orientation
monitor=eDP-1,1280x800@90,0x0,1

# External monitor configuration (auto-detect)
monitor=,preferred,auto,1
EOF

    print_status "Display orientation configuration created"
}

# Configure power management for Steam Deck
configure_power_management() {
    print_status "Configuring power management for Steam Deck..."

    # Install power management tools
    yay -S --noconfirm power-profiles-daemon

    # Set balanced power profile for battery operation
    sudo systemctl enable power-profiles-daemon
    sudo systemctl start power-profiles-daemon

    # Configure for balanced mode (good for Steam Deck)
    powerprofilesctl set balanced

    print_status "Power management configured"
}

# Configure Steam Deck controls
configure_steam_deck_controls() {
    print_status "Configuring Steam Deck controls..."

    # Install Steam controller support
    yay -S --noconfirm steam-devices

    # Add user to input group
    sudo usermod -a -G input $USER

    # Configure udev rules for Steam controller
    sudo tee /etc/udev/rules.d/99-steam-controller.rules > /dev/null <<EOF
# Steam Controller udev rules
SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", MODE="0666"
KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"
EOF

    sudo udevadm control --reload-rules

    print_status "Steam Deck controls configured"
}

# Install Steam
install_steam() {
    print_status "Installing Steam..."

    # Enable multilib repository
    if ! grep -q "multilib" /etc/pacman.conf; then
        print_status "Enabling multilib repository..."
        sudo sed -i '/^#\[multilib\]/,/^$/{s/^#//}' /etc/pacman.conf
        sudo pacman -Sy
    fi

    # Install Steam
    yay -S --noconfirm steam

    print_status "Steam installed"
}

# Configure fan control
configure_fan_control() {
    print_status "Configuring fan control..."

    # Install fan control daemon
    yay -S --noconfirm jupiter-fan-control

    # Enable fan control service
    sudo systemctl enable jupiter-fan-control
    sudo systemctl start jupiter-fan-control

    print_status "Fan control configured"
}

# Create desktop shortcut for Steam Deck mode
create_steam_deck_shortcuts() {
    print_status "Creating Steam Deck shortcuts..."

    # Create desktop file for Steam Big Picture mode
    mkdir -p ~/.local/share/applications

    cat > ~/.local/share/applications/steam-gamemode.desktop << 'EOF'
[Desktop Entry]
Name=Steam (Game Mode)
Comment=Steam Big Picture Mode
Exec=steam -bigpicture
Icon=steam
Terminal=false
Type=Application
Categories=Game;
EOF

    print_status "Steam Deck shortcuts created"
}

# Configure system for gaming
configure_gaming_optimizations() {
    print_status "Configuring gaming optimizations..."

    # Install gaming-related packages
    yay -S --noconfirm gamemode lib32-gamemode mangohud lib32-mangohud

    # Configure gamemode
    sudo usermod -a -G gamemode $USER

    print_status "Gaming optimizations configured"
}

# Update bootloader for Steam Deck
update_bootloader() {
    print_status "Updating bootloader configuration..."

    # Add Steam Deck specific kernel parameters
    if [[ -f /etc/default/grub ]]; then
        # Backup grub config
        sudo cp /etc/default/grub /etc/default/grub.backup

        # Add Steam Deck specific parameters
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& amd_pstate=active/' /etc/default/grub

        # Regenerate grub config
        sudo grub-mkconfig -o /boot/grub/grub.cfg

        print_status "Bootloader updated"
    fi
}

# Fix screen rotation at boot
fix_boot_screen_rotation() {
    print_status "Fixing screen rotation at boot..."

    # Add fbcon rotation parameter to bootloader
    if [[ -f /etc/default/grub ]]; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& fbcon=rotate:0/' /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        print_status "Boot screen rotation fixed"
    fi
}

# Main installation function
main() {
    print_status "Starting Steam Deck OLED post-Omarchy installation..."

    # Check if running on Steam Deck
    check_steam_deck

    # Install packages
    install_steam_deck_packages

    # Fix hardware issues
    fix_wifi
    fix_bluetooth
    fix_audio
    fix_display_orientation

    # Configure system
    configure_power_management
    configure_steam_deck_controls
    configure_fan_control

    # Install gaming software
    install_steam
    configure_gaming_optimizations

    # Create shortcuts
    create_steam_deck_shortcuts

    # Update bootloader
    update_bootloader
    fix_boot_screen_rotation

    print_status "Installation complete!"
    print_warning "Please reboot your Steam Deck to apply all changes."
    print_warning "After reboot, you may need to:"
    print_warning "1. Set up Steam in Desktop Mode"
    print_warning "2. Configure display settings if needed"
    print_warning "3. Test audio, WiFi, and Bluetooth functionality"

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Steam Deck OLED setup completed!${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Run main function
main "$@" 
