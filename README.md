<div align="center">
<img src="https://i.imgur.com/Dd1UJYI.png" alt="Qm-Zqt55w-HXr-Zzh-Bih-SVz-XDvwp9rguv-LAv-Fh-Um1q-JR6-GYe-Q" border="0" width="80%">
</div>

---

# Steam Deck OLED Setup Script

Post-installation setup script for Steam Deck OLED hardware support after installing Omarchy on Arch Linux.

## What the script does

**Hardware Support:**

- Installs Neptune kernel (linux-neptune) for OLED hardware compatibility
- Adds Steam Deck audio DSP and ALSA UCM configuration
- Enables Jupiter fan control for proper thermal management
- Installs Steam and controller support

**Display Configuration:**

- Creates Hyprland monitor configuration with 1.6× scaling and rotation for built-in display
- Fixes Omarchy's GDK_SCALE=2 issue for external monitor compatibility
- Sets up proper environment variables for multi-monitor setups

**System Services:**

- Enables Bluetooth, power management, and audio services
- Configures AMD pstate optimization in GRUB bootloader

## Installation

**Prerequisites:**

1. Arch Linux installed on Steam Deck OLED
2. Omarchy installed ([installation guide](https://github.com/basecamp/omarchy))
3. Multilib repository enabled in `/etc/pacman.conf`

**Quick Install:**

```bash
curl -sSL https://raw.githubusercontent.com/aorumbayev/deckarchy/main/steam-deck-oled-fix.sh | bash
```

**Manual Install:**

```bash
git clone https://github.com/aorumbayev/deckarchy.git
cd deckarchy
chmod +x steam-deck-oled-fix.sh
./steam-deck-oled-fix.sh
```

## Options

- `--dry-run` - Show what would be done without making changes
- `--yes` - Run without prompting for confirmation

## What gets installed

**Core packages:**

- `steam` - Steam client and controller support
- `power-profiles-daemon` - Power management
- `bluez` and `bluez-utils` - Bluetooth support
- `brightnessctl` - Screen brightness control

**Steam Deck specific packages:**

- `linux-neptune` and `linux-neptune-headers` - OLED-compatible kernel
- `linux-firmware-neptune` - Hardware firmware
- `steamdeck-dsp` - Audio DSP support
- `alsa-ucm-conf` - Audio configuration
- `jupiter-fan-control` - Fan control

## Important notes

- **Reboot required** after running the script
- Script automatically detects Steam Deck vs generic systems
- Creates backup of GRUB configuration before modification
- Designed to complement Omarchy, not replace it

## License

MIT License - see [LICENSE](LICENSE) file.
