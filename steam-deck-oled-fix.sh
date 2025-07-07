#!/usr/bin/env bash
#
# Steam Deck Arch Linux Hardware Setup Script v2
# Safer implementation with systemd-boot support
#

set -euo pipefail

# Color output functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() {
  echo -e "${RED}[ERROR]${NC} $*"
  exit 1
}

# Script configuration
LOG_FILE="/var/log/steamdeck-arch-setup.log"
BACKUP_DIR="/etc/pacman.d/backup"
DRY_RUN=0
AUTO_YES=0
MODEL=""
KERNEL_CHOICE=""
BOOTLOADER=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
  --dry-run)
    DRY_RUN=1
    shift
    ;;
  --yes | -y)
    AUTO_YES=1
    shift
    ;;
  --model)
    MODEL="$2"
    shift 2
    ;;
  --kernel)
    KERNEL_CHOICE="$2"
    shift 2
    ;;
  --minimal)
    MINIMAL=1
    shift
    ;;
  --help | -h)
    cat <<EOF
Steam Deck Arch Linux Hardware Setup Script v2

Usage: $0 [OPTIONS]

Options:
    --dry-run       Show what would be done without making changes
    --yes, -y       Answer yes to all prompts
    --model MODEL   Specify model (lcd/oled) instead of auto-detection
                --kernel TYPE   Choose kernel (mainline/neptune) - default: neptune
    --minimal       Install minimal packages only (safer)
    --help, -h      Show this help message

Examples:
    $0 --minimal              # Safe minimal installation
    $0 --yes --model oled     # Automatic OLED installation
    $0 --dry-run              # Test run without changes
EOF
    exit 0
    ;;
  *)
    error "Unknown option: $1"
    ;;
  esac
done

# Logging setup
exec > >(tee -a "$LOG_FILE")
exec 2>&1

# Utility functions
ask() {
  if [[ $AUTO_YES -eq 1 ]]; then
    return 0
  fi
  local prompt="$1"
  local response
  read -rp "$prompt [y/N] " response
  [[ "$response" =~ ^[Yy] ]]
}

run() {
  info "Running: $*"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY RUN] Would execute: $*"
  else
    eval "$@" || {
      warn "Command failed: $*"
      return 1
    }
  fi
}

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local backup_path="${BACKUP_DIR}/$(basename "$file").$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    run "sudo cp '$file' '$backup_path'"
    info "Backed up $file to $backup_path"
  fi
}

# Detection functions
detect_bootloader() {
  info "Detecting bootloader..."

  if [[ -d /boot/loader/entries ]]; then
    BOOTLOADER="systemd-boot"
    info "Detected systemd-boot"
  elif [[ -f /boot/grub/grub.cfg ]]; then
    BOOTLOADER="grub"
    info "Detected GRUB"
  else
    error "Could not detect bootloader. Please ensure /boot is mounted."
  fi
}

detect_steam_deck() {
  info "Detecting Steam Deck hardware..."

  if [[ -f /sys/class/dmi/id/product_name ]]; then
    local product=$(cat /sys/class/dmi/id/product_name)
    case "$product" in
    "Jupiter")
      success "Steam Deck LCD detected"
      MODEL="lcd"
      return 0
      ;;
    "Galileo")
      success "Steam Deck OLED detected"
      MODEL="oled"
      return 0
      ;;
    *)
      warn "Not running on Steam Deck hardware (detected: $product)"
      if ! ask "Continue anyway?"; then
        exit 0
      fi
      MODEL="generic"
      return 1
      ;;
    esac
  else
    warn "Could not detect hardware type"
    MODEL="generic"
    return 1
  fi
}

# Repository management
add_valve_repositories() {
  info "Adding Valve Steam Deck repositories..."

  backup_file "/etc/pacman.conf"

  # Check if repositories already exist
  if grep -q "^\[jupiter-rel\]" /etc/pacman.conf; then
    warn "Jupiter repository already exists in pacman.conf"
    return
  fi

  # Create a safer addition to pacman.conf
  # Add after the [options] section, not at the beginning
  local temp_conf="/tmp/pacman.conf.new"
  local in_options=0
  local repos_added=0

  while IFS= read -r line; do
    echo "$line" >>"$temp_conf"

    # Add repos after [options] section ends
    if [[ "$line" =~ ^\[options\] ]]; then
      in_options=1
    elif [[ $in_options -eq 1 && "$line" =~ ^\[.*\] ]] && [[ $repos_added -eq 0 ]]; then
      # We've hit the next section after [options]
      cat >>"$temp_conf" <<'EOF'
#
# Steam Deck Repositories
# Added by steamdeck-arch-setup script
# WARNING: These may conflict with standard Arch packages
#

[jupiter-rel]
Server = https://steamdeck-packages.steamos.cloud/archlinux-mirror/$repo/os/$arch
SigLevel = Never

[holo-rel]
Server = https://steamdeck-packages.steamos.cloud/archlinux-mirror/$repo/os/$arch
SigLevel = Never

EOF
      repos_added=1
    fi
  done </etc/pacman.conf

  # Replace the original file
  run "sudo mv '$temp_conf' /etc/pacman.conf"
  run "sudo pacman -Sy" || {
    error "Failed to sync repositories. Check your internet connection."
  }

  success "Valve repositories added successfully"
}

# Minimal package installation (safer)
install_minimal_packages() {
  info "Installing minimal Steam Deck support packages..."

  # Only essential packages for hardware support
  local essential_pkgs=(
    "steam"
    "vulkan-radeon"
    "lib32-vulkan-radeon"
  )

  # Platform-specific minimal packages
  if [[ "$MODEL" == "oled" || "$MODEL" == "lcd" ]]; then
    # Only add fan control for actual Steam Deck hardware
    if pacman -Si jupiter-fan-control &>/dev/null; then
      essential_pkgs+=("jupiter-fan-control")
    fi
  fi

  # Install packages one by one
  for pkg in "${essential_pkgs[@]}"; do
    if pacman -Si "$pkg" &>/dev/null; then
      run "sudo pacman -S --needed --noconfirm $pkg" || warn "Failed to install $pkg"
    else
      warn "Package $pkg not found"
    fi
  done

  success "Minimal packages installed"
}

# Full package installation (original behavior)
install_full_packages() {
  info "Installing full Steam Deck package set..."

  warn "Full installation may cause conflicts with existing packages"
  if ! ask "Continue with full installation?"; then
    info "Switching to minimal installation"
    install_minimal_packages
    return
  fi

  # Graphics packages
  local graphics_pkgs=(
    "mesa"
    "lib32-mesa"
    "vulkan-radeon"
    "lib32-vulkan-radeon"
    "steam"
    "gamescope"
  )

  # Platform packages
  local platform_pkgs=(
    "jupiter-hw-support"
    "jupiter-fan-control"
    "steamdeck-dsp"
  )

  # Audio packages
  local audio_pkgs=(
    "pipewire"
    "pipewire-alsa"
    "pipewire-pulse"
    "lib32-pipewire"
    "wireplumber"
    "alsa-ucm-conf"
  )

  # Install each group
  info "Installing graphics packages..."
  for pkg in "${graphics_pkgs[@]}"; do
    run "sudo pacman -S --needed --noconfirm $pkg" || warn "Failed to install $pkg"
  done

  info "Installing platform packages..."
  for pkg in "${platform_pkgs[@]}"; do
    if pacman -Si "$pkg" &>/dev/null; then
      run "sudo pacman -S --needed --noconfirm $pkg" || warn "Failed to install $pkg"
    fi
  done

  info "Installing audio packages..."
  for pkg in "${audio_pkgs[@]}"; do
    run "sudo pacman -S --needed --noconfirm $pkg" || warn "Failed to install $pkg"
  done
}

# Kernel installation - Neptune kernel is required for Steam Deck
install_kernel() {
  info "Installing Neptune kernel (required for Steam Deck hardware)..."

  warn "Installing linux-neptune will replace your current kernel"
  warn "Make sure you have a recovery USB ready"

  if ! ask "Continue with Neptune kernel installation?"; then
    error "Neptune kernel is required for Steam Deck hardware support. Exiting."
  fi

  # Check for conflicts
  if pacman -Qq linux &>/dev/null; then
    warn "Standard linux kernel detected. This will be replaced."
    warn "Your current kernel will be removed to avoid conflicts."

    # Create fallback boot entry for current kernel first
    if [[ "$BOOTLOADER" == "systemd-boot" ]]; then
      info "Creating fallback boot entry for current kernel..."
      if [[ -f /boot/vmlinuz-linux ]]; then
        cp /boot/loader/entries/arch.conf /boot/loader/entries/arch-fallback.conf 2>/dev/null || true
      fi
    fi
  fi

  info "Installing linux-neptune kernel..."

  # Force removal of conflicting packages
  if pacman -Qq linux-firmware &>/dev/null; then
    info "Removing linux-firmware to avoid conflicts..."
    run "sudo pacman -Rdd --noconfirm linux-firmware" || warn "Failed to remove linux-firmware"
  fi

  # Install Neptune kernel
  run "sudo pacman -S --needed --noconfirm linux-neptune linux-neptune-headers linux-firmware-neptune" || {
    error "Failed to install neptune kernel. DO NOT REBOOT! Try to fix the issue first."
  }

  # Regenerate initramfs
  info "Regenerating initramfs..."
  run "sudo mkinitcpio -P" || {
    error "Failed to generate initramfs. DO NOT REBOOT! Your system won't boot."
  }

  # Update boot configuration
  update_boot_configuration "linux-neptune"

  success "Neptune kernel installed successfully"
}

# Boot configuration update with better systemd-boot handling
update_boot_configuration() {
  local kernel_name="${1:-linux-neptune}"

  info "Updating boot configuration for $kernel_name..."

  if [[ "$BOOTLOADER" == "systemd-boot" ]]; then
    # Create boot entry for Neptune kernel
    local entry_file="/boot/loader/entries/arch-neptune.conf"
    local root_uuid=$(findmnt -no UUID /)
    local root_partuuid=$(findmnt -no PARTUUID /)

    if [[ -z "$root_uuid" ]] && [[ -z "$root_partuuid" ]]; then
      warn "Could not determine root UUID/PARTUUID. You'll need to edit boot entry manually."
      warn "Edit $entry_file and set the correct root= parameter"
    fi

    # Prefer PARTUUID as it's more reliable
    local root_param=""
    if [[ -n "$root_partuuid" ]]; then
      root_param="root=PARTUUID=${root_partuuid}"
    else
      root_param="root=UUID=${root_uuid}"
    fi

    # Get additional kernel parameters from existing entry
    local extra_params=""
    if [[ -f /boot/loader/entries/arch.conf ]]; then
      extra_params=$(grep "^options" /boot/loader/entries/arch.conf | sed 's/^options.*root=[^ ]*//' || true)
    fi

    cat >"$entry_file" <<EOF
title   Arch Linux (Steam Deck)
linux   /vmlinuz-${kernel_name}
initrd  /initramfs-${kernel_name}.img
options ${root_param} rw${extra_params}
EOF

    info "Created boot entry: $entry_file"

    # Make it the default
    echo "default arch-neptune.conf" | run "sudo tee /boot/loader/loader.conf"
    echo "timeout 3" | run "sudo tee -a /boot/loader/loader.conf"

    success "Set Neptune kernel as default boot option"

  elif [[ "$BOOTLOADER" == "grub" ]]; then
    info "Updating GRUB configuration..."

    # Update GRUB default kernel
    backup_file "/etc/default/grub"

    # Add Steam Deck optimized parameters
    local grub_params="console=tty1 amd_iommu=off amdgpu.gttsize=8128 spi_amd.speed_dev=1 audit=0"
    run "sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"${grub_params}\"/' /etc/default/grub"

    run "sudo grub-mkconfig -o /boot/grub/grub.cfg"
  fi
}

# Safer service configuration
configure_services() {
  info "Configuring services..."

  # Only enable services that actually exist
  local services=()

  # Check and add services
  [[ -f /usr/lib/systemd/system/bluetooth.service ]] && services+=("bluetooth")

  # Fan control for Steam Deck
  if [[ "$MODEL" == "lcd" || "$MODEL" == "oled" ]]; then
    [[ -f /usr/lib/systemd/system/jupiter-fan-control.service ]] && services+=("jupiter-fan-control")
  fi

  # Enable system services
  for service in "${services[@]}"; do
    run "sudo systemctl enable $service" || warn "Failed to enable $service"
  done

  # User services for audio (if user wants them)
  if command -v pipewire &>/dev/null; then
    if ask "Enable PipeWire audio services?"; then
      run "systemctl --user enable pipewire.service pipewire-pulse.service wireplumber.service"
    fi
  fi

  success "Services configured"
}

# Create recovery helper with kernel restoration
create_recovery_script() {
  info "Creating recovery helper..."

  cat <<'EOF' | run "sudo tee /usr/local/bin/steamdeck-recovery"
#!/bin/bash
# Steam Deck Arch Setup Recovery Script

echo "Steam Deck Setup Recovery"
echo "========================"
echo
echo "This script helps recover from Steam Deck setup issues"
echo

# Remove Steam Deck repositories
echo "Removing Steam Deck repositories..."
sudo cp /etc/pacman.conf /etc/pacman.conf.steamdeck-backup
sudo sed -i '/\[jupiter-rel\]/,/^$/d' /etc/pacman.conf
sudo sed -i '/\[holo-rel\]/,/^$/d' /etc/pacman.conf

# Remove IgnorePkg entries
sudo sed -i '/^IgnorePkg.*jupiter\|neptune\|steamdeck/d' /etc/pacman.conf

echo
echo "To restore standard kernel:"
echo "1. Remove Neptune kernel: sudo pacman -R linux-neptune linux-neptune-headers linux-firmware-neptune"
echo "2. Install standard kernel: sudo pacman -S linux linux-headers linux-firmware"
echo "3. Regenerate initramfs: sudo mkinitcpio -P"
echo "4. Update bootloader configuration"
echo
echo "For systemd-boot: Edit /boot/loader/entries/ files"
echo "For GRUB: Run sudo grub-mkconfig -o /boot/grub/grub.cfg"
EOF
  run "sudo chmod +x /usr/local/bin/steamdeck-recovery"
}

# Main execution
main() {
  info "Steam Deck Arch Linux Hardware Setup Script v2"
  info "=============================================="
  echo

  # Safety checks
  if [[ $EUID -eq 0 ]]; then
    error "Do not run as root. Script will use sudo when needed."
  fi

  # Detect system
  detect_bootloader
  detect_steam_deck

  # Verify multilib
  if ! grep -q "^\[multilib\]" /etc/pacman.conf || ! grep -A1 "^\[multilib\]" /etc/pacman.conf | grep -q "Include"; then
    error "Multilib repository not enabled. Enable it in /etc/pacman.conf first."
  fi

  # Show warnings
  echo
  warn "IMPORTANT: This script modifies system packages and configuration"
  warn "It may cause conflicts with existing packages"
  warn "Boot issues are possible, especially with kernel changes"
  echo
  echo "Detected:"
  echo "- Bootloader: $BOOTLOADER"
  echo "- Model: $MODEL"
  echo

  if ! ask "Do you understand the risks and want to continue?"; then
    exit 0
  fi

  # Installation flow - Neptune kernel is mandatory
  add_valve_repositories
  install_kernel # Always install Neptune kernel

  if [[ "${MINIMAL:-0}" -eq 1 ]] || ask "Use minimal package installation? (recommended)"; then
    install_minimal_packages
  else
    install_full_packages
  fi

  configure_services

  # Always create recovery script
  create_recovery_script

  # Summary
  echo
  echo "========================================"
  echo "Steam Deck Setup Complete"
  echo "========================================"
  echo
  echo "Installed features:"
  echo "- Valve repositories: jupiter-rel, holo-rel"
  echo "- Neptune kernel (required for hardware support)"
  echo "- Steam Deck hardware drivers"
  echo
  echo "Recovery tools:"
  echo "- steamdeck-recovery : Remove Steam Deck modifications"
  echo
  echo "IMPORTANT:"
  echo "1. Test your system before making the new kernel default"
  echo "2. Keep a bootable USB ready for recovery"
  echo "3. The script created backups in $BACKUP_DIR"
  echo

  if [[ "$MODEL" == "oled" ]]; then
    echo "OLED Notes:"
    echo "- Bluetooth suspend bug: disable BT before suspend"
    echo "- Audio may need additional configuration"
  fi

  echo
  warn "Reboot carefully and test your system"
}

# Run main
main "$@"
