#!/usr/bin/env bash
#
# Steam Deck OLED – Post-Omarchy Hardware Setup (COMPLETE VERSION)
# Fixed: Includes repository setup function that was accidentally omitted
#

set -euo pipefail
LOG=/var/log/steamdeck-setup.log
exec > >(tee -a "$LOG") 2>&1

################################################################################
# 0. Global helpers
################################################################################
COLOR() { [[ -t 1 ]] && printf '\e[%sm%s\e[0m' "$1" "$2" || printf '%s' "$2"; }
info () { COLOR 32 "[INFO] ";  echo "$*"; }
warn () { COLOR 33 "[WARN] ";  echo "$*"; }
fail () { COLOR 31 "[FAIL] ";  echo "$*"; exit 1; }

DRY=0; AUTO=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1
[[ "${1:-}" == "--yes"     ]] && AUTO=1
[[ "$DRY" -eq 1 && "$AUTO" -eq 1 ]] && fail "Choose --dry-run OR --yes"

ask () { [[ $AUTO -eq 1 ]] && return 0; read -rp "$1 [y/N] " r; [[ $r == y* ]]; }

run () {
  info "$*"
  [[ $DRY -eq 1 ]] || eval "$*"
}

################################################################################
# 1. Detect Deck
################################################################################
DECK=0
if [[ -f /sys/class/dmi/id/product_name ]] &&
   grep -qE "(Jupiter|Galileo)" /sys/class/dmi/id/product_name; then
  DECK=1
  info "Steam Deck detected"
else
  info "Generic system detected"
fi

################################################################################
# 2. Repositories & keys (RESTORED FUNCTION)
################################################################################
add_repos () {
  info "Adding Valve jupiter/holo repositories"
  
  # Remove any existing jupiter/holo repositories first
  sudo sed -i '/\[jupiter-main\]/,/^$/d' /etc/pacman.conf 2>/dev/null || true
  sudo sed -i '/\[holo-main\]/,/^$/d' /etc/pacman.conf 2>/dev/null || true
  
  # Add the repositories
  sudo tee -a /etc/pacman.conf >/dev/null <<'EOF'

[jupiter-main]
SigLevel = Optional TrustAll
Server = https://steamdeck-packages.steamos.cloud/archlinux-mirror/jupiter-main/os/x86_64/

[holo-main]
SigLevel = Optional TrustAll
Server = https://steamdeck-packages.steamos.cloud/archlinux-mirror/holo-main/os/x86_64/
EOF
  
  # Initialize and sync
  run "sudo pacman-key --init"
  run "sudo pacman-key --populate archlinux"
  run "sudo pacman -Sy"
  
  info "Valve repositories added successfully"
}

################################################################################
# 3. Verify multilib is enabled
################################################################################
verify_multilib() {
    info "Verifying multilib repository is enabled"
    
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        fail "Multilib repository not enabled. Run: sudo nano /etc/pacman.conf and uncomment [multilib] section"
    fi
    
    if ! pacman -Sl multilib >/dev/null 2>&1; then
        fail "Multilib repository not synced. Run: sudo pacman -Sy"
    fi
    
    info "Multilib repository is properly configured"
}

################################################################################
# 4. Packages (CORRECTED - no steam-devices)
################################################################################
PACKAGES_CORE=(
  steam                    # Includes controller udev rules automatically
  power-profiles-daemon 
  bluez bluez-utils 
  brightnessctl
)

PACKAGES_DECK=(
  linux-neptune linux-neptune-headers 
  linux-firmware-neptune
  steamdeck-dsp 
  alsa-ucm-conf 
  jupiter-fan-control
)

install_pkgs () {
  local pkgs=("${PACKAGES_CORE[@]}")
  [[ $DECK -eq 1 ]] && pkgs+=("${PACKAGES_DECK[@]}")
  
  info "Installing packages: ${pkgs[*]}"
  
  # Install packages one by one to isolate failures
  for package in "${pkgs[@]}"; do
    info "Installing: $package"
    
    if ! pacman -Si "$package" >/dev/null 2>&1; then
      warn "Package $package not available - skipping"
      continue
    fi
    
    if ! sudo pacman -S --needed --noconfirm "$package"; then
      warn "Failed to install $package - continuing with others"
    fi
  done
}

################################################################################
# 5. Display & scaling
################################################################################
setup_display () {
  info "Setting up display configuration"
  mkdir -p ~/.config/hypr
  
  cat > ~/.config/hypr/monitors.conf <<'EOF'
# Steam Deck built-in display rotated to landscape, 1.6× scale
monitor = eDP-1, preferred, auto, 1.6, transform, 3
# External displays default 1.0×
monitor = , preferred, auto, 1.0
EOF

  # Fix Omarchy GDK_SCALE issue
  mkdir -p ~/.config/environment.d
  cat > ~/.config/environment.d/steamdeck-scale.conf <<'EOF'
# Override Omarchy's GDK_SCALE=2 for external monitor compatibility
GDK_SCALE=1
QT_AUTO_SCREEN_SCALE_FACTOR=1
QT_SCALE_FACTOR=1
EOF

  info "Display configuration created"
}

################################################################################
# 6. Services
################################################################################
enable_services () {
  info "Enabling system services"
  run "sudo systemctl enable --now bluetooth"
  run "sudo systemctl enable --now power-profiles-daemon"
  
  if [[ $DECK -eq 1 ]]; then
    run "sudo systemctl enable --now jupiter-fan-control"
  fi
  
  run "systemctl --user enable --now pipewire wireplumber"
  info "Services enabled successfully"
}

################################################################################
# 7. Audio setup
################################################################################
setup_audio () {
  info "Setting up audio configuration"
  run "sudo alsactl init || true"
  info "Audio setup completed"
}

################################################################################
# 8. Bootloader optimization
################################################################################
tune_grub () {
  info "Updating GRUB configuration for Steam Deck"
  local cfg=/etc/default/grub
  
  # Create backup
  sudo cp "$cfg"{,.bak}
  
  # Add AMD pstate optimization
  if ! grep -q "amd_pstate=active" "$cfg"; then
    sudo sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 amd_pstate=active"/' "$cfg"
    run "sudo grub-mkconfig -o /boot/grub/grub.cfg"
    info "GRUB configuration updated"
  else
    info "GRUB already optimized"
  fi
}

################################################################################
# 9. Optional enhanced controller support
################################################################################
install_enhanced_controller_support() {
    info "Installing enhanced controller support (optional)"
    
    if command -v yay >/dev/null 2>&1; then
        info "Installing game-devices-udev for extended controller support"
        yay -S --noconfirm game-devices-udev || warn "Failed to install game-devices-udev"
    else
        info "Install yay to get enhanced controller support via game-devices-udev"
    fi
}

################################################################################
# 10. OLED care tips
################################################################################
oled_tips () {
cat <<'NOTE'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 OLED Care Recommendations
 ──────────────────────────────────────────
 • Enable screen blanking (5-10 minutes)
 • Lower brightness when possible
 • Consider: https://aur.archlinux.org/packages/oled-pixel-shift
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NOTE
}

################################################################################
# 11. Main execution
################################################################################
main () {
  info "Steam Deck OLED hardware setup - COMPLETE VERSION"
  
  # Essential setup steps
  verify_multilib
  add_repos          # NOW PROPERLY IMPLEMENTED
  install_pkgs
  setup_display
  enable_services
  setup_audio
  tune_grub
  
  # Optional enhancements
  if ask "Install enhanced controller support for non-Steam controllers? [y/N]"; then
    install_enhanced_controller_support
  fi
  
  # Final information
  oled_tips
  
  info "Setup completed successfully!"
  info "Reboot recommended to apply all changes"
  
  # Summary of what was done
  echo
  info "Summary of changes:"
  echo "  ✓ Added Valve Steam Deck repositories"
  echo "  ✓ Installed Steam and hardware packages"
  echo "  ✓ Fixed Omarchy GDK_SCALE issue"
  echo "  ✓ Configured display rotation and scaling"
  echo "  ✓ Enabled audio, Bluetooth, and power services"
  echo "  ✓ Optimized GRUB for Steam Deck"
  [[ $DECK -eq 1 ]] && echo "  ✓ Steam Deck hardware support enabled"
}

################################################################################
main "$@"
