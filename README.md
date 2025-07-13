<div align="center">
<img src="https://i.imgur.com/Dd1UJYI.png" alt="Qm-Zqt55w-HXr-Zzh-Bih-SVz-XDvwp9rguv-LAv-Fh-Um1q-JR6-GYe-Q" border="0" width="80%">
</div>

---

# Linux Neptune Kernel Setup

⚠️ **EXPERIMENTAL** - Only tested on Steam Deck OLED model

Clean Neptune kernel installation script for Steam Deck and compatible Arch systems.

## Features

- Detects Steam Deck hardware automatically
- Installs Neptune kernel (linux-neptune-611) with hardware support
- Configures audio DSP and firmware for Steam Deck
- Handles bootloader configuration automatically

## Installation

**Prerequisites:** 
- Fresh Arch Linux installation with sudo privileges
- Must be run AFTER vanilla Arch install but BEFORE Omarchy configuration

```bash
curl -sSL https://raw.githubusercontent.com/aorumbayev/deckarchy/main/linux-neptune.sh | bash
```

**After installation:**
1. Reboot system
2. Boot into Neptune kernel from bootloader menu
3. Proceed with Omarchy installation

## Credits

This setup uses a modified version of the helper script from [Chris Titus Tech's LinUtil](https://github.com/ChrisTitusTech/linutil) repository. Special thanks to the LinUtil project for their excellent system utilities and automation tools.

## License

MIT License - see [LICENSE](LICENSE) file.
