#!/bin/sh -e

. ./common-script.sh

detectSteamDeck() {
    STEAM_DECK=0
    if [ -f /sys/class/dmi/id/product_name ] && 
       grep -qE "(Jupiter|Galileo)" /sys/class/dmi/id/product_name; then
        STEAM_DECK=1
        printf "%b\n" "${GREEN}Steam Deck detected${RC}"
    else
        printf "%b\n" "${YELLOW}Generic system detected - continuing with Neptune kernel installation${RC}"
    fi
}

setUpRepos() {
    if ! grep -q "^\s*\[jupiter-staging\]" /etc/pacman.conf; then
        printf "%b\n" "${CYAN}Adding jupiter-staging to pacman repositories...${RC}"
        echo "[jupiter-staging]" | "$ESCALATION_TOOL" tee -a /etc/pacman.conf
        echo "Server = https://steamdeck-packages.steamos.cloud/archlinux-mirror/\$repo/os/\$arch" | "$ESCALATION_TOOL" tee -a /etc/pacman.conf
        echo "SigLevel = Never" | "$ESCALATION_TOOL" tee -a /etc/pacman.conf
    fi
    if ! grep -q "^\s*\[holo-staging\]" /etc/pacman.conf; then
        printf "%b\n" "${CYAN}Adding holo-staging to pacman repositories...${RC}"
        echo "[holo-staging]" | "$ESCALATION_TOOL" tee -a /etc/pacman.conf
        echo "Server = https://steamdeck-packages.steamos.cloud/archlinux-mirror/\$repo/os/\$arch" | "$ESCALATION_TOOL" tee -a /etc/pacman.conf
        echo "SigLevel = Never" | "$ESCALATION_TOOL" tee -a /etc/pacman.conf
    fi
}

installKernel() {
    if [ "$STEAM_DECK" -eq 1 ]; then
        printf "%b\n" "${CYAN}Installing Steam Deck Neptune kernel packages...${RC}"
        PACKAGES="linux-neptune-611 linux-neptune-611-headers steamdeck-dsp jupiter-staging/alsa-ucm-conf linux-firmware-neptune"
    else
        printf "%b\n" "${CYAN}Installing Neptune kernel for generic system...${RC}"
        PACKAGES="linux-neptune-611 linux-neptune-611-headers linux-firmware-neptune"
    fi

    if "$PACKAGER" -Q | grep -q "\blinux-neptune"; then
        printf "%b\n" "${YELLOW}Existing Neptune kernel detected. Upgrading to latest version...${RC}"
        "$ESCALATION_TOOL" "$PACKAGER" -Syyu --noconfirm
        "$ESCALATION_TOOL" "$PACKAGER" -Rdd --noconfirm linux-firmware 2>/dev/null || true
        "$ESCALATION_TOOL" "$PACKAGER" -Rdd --noconfirm linux-firmware-amdgpu linux-firmware-atheros linux-firmware-broadcom linux-firmware-cirrus linux-firmware-intel linux-firmware-mediatek linux-firmware-nvidia linux-firmware-other linux-firmware-radeon linux-firmware-realtek 2>/dev/null || true
        "$ESCALATION_TOOL" "$PACKAGER" -S --noconfirm $PACKAGES
        "$ESCALATION_TOOL" mkinitcpio -P
    else
        printf "%b\n" "${CYAN}Installing Neptune kernel...${RC}"
        "$ESCALATION_TOOL" "$PACKAGER" -Syyu --noconfirm
        "$ESCALATION_TOOL" "$PACKAGER" -Rdd --noconfirm linux-firmware 2>/dev/null || true
        "$ESCALATION_TOOL" "$PACKAGER" -Rdd --noconfirm linux-firmware-amdgpu linux-firmware-atheros linux-firmware-broadcom linux-firmware-cirrus linux-firmware-intel linux-firmware-mediatek linux-firmware-nvidia linux-firmware-other linux-firmware-radeon linux-firmware-realtek 2>/dev/null || true
        "$ESCALATION_TOOL" "$PACKAGER" -S --noconfirm $PACKAGES
        "$ESCALATION_TOOL" mkinitcpio -P
    fi

    if [ -f /etc/default/grub ]; then
        printf "%b\n" "${CYAN}Updating GRUB...${RC}"
        if ! grep -q '^UPDATEDEFAULT=' /etc/default/grub; then
            echo 'UPDATEDEFAULT=yes' | "$ESCALATION_TOOL" tee -a /etc/default/grub
        else
            "$ESCALATION_TOOL" sed -i 's/^UPDATEDEFAULT=.*/UPDATEDEFAULT=yes/' /etc/default/grub
        fi
        if [ -f /boot/grub/grub.cfg ]; then
            "$ESCALATION_TOOL" grub-mkconfig -o /boot/grub/grub.cfg
        else
            printf "%b\n" "${RED}GRUB configuration file not found. Run grub-mkconfig manually.${RC}"
        fi
    elif [ -d /boot/loader/entries ]; then
        printf "%b\n" "${CYAN}Detected systemd-boot. Regenerating boot entries...${RC}"
        "$ESCALATION_TOOL" mkinitcpio -P
        if command -v kernel-install >/dev/null 2>&1; then
            if pacman -Q linux-neptune-611 >/dev/null 2>&1; then
                "$ESCALATION_TOOL" kernel-install add "$(pacman -Q linux-neptune-611 | cut -d' ' -f2)" /boot/vmlinuz-linux-neptune-611
            else
                "$ESCALATION_TOOL" kernel-install add "$(pacman -Q linux-neptune | cut -d' ' -f2)" /boot/vmlinuz-linux-neptune
            fi
        else
            printf "%b\n" "${YELLOW}kernel-install not found. Boot entry creation may need manual intervention.${RC}"
            printf "%b\n" "${CYAN}Tip: Run 'sudo bootctl install' if systemd-boot needs setup.${RC}"
        fi
    else
        printf "%b\n" "${RED}No supported bootloader detected (GRUB or systemd-boot). Manually configure your bootloader to use linux-neptune.${RC}"
    fi
}

copyFirmwareFiles() {
    if [ "$STEAM_DECK" -eq 1 ]; then
        printf "%b\n" "${CYAN}Copying Steam Deck firmware files...${RC}"
        "$ESCALATION_TOOL" mkdir -p /usr/lib/firmware/cirrus
        
        for firmware_file in \
            "cs35l41-dsp1-spk-cali.bin" \
            "cs35l41-dsp1-spk-cali.wmfw" \
            "cs35l41-dsp1-spk-prot.bin" \
            "cs35l41-dsp1-spk-prot.wmfw"; do
            
            if [ -f "/usr/lib/firmware/$firmware_file" ]; then
                "$ESCALATION_TOOL" cp "/usr/lib/firmware/$firmware_file" /usr/lib/firmware/cirrus/
                printf "%b\n" "${GREEN}Copied $firmware_file${RC}"
            else
                printf "%b\n" "${YELLOW}Warning: $firmware_file not found - OLED audio may require manual firmware installation${RC}"
            fi
        done
        
        if [ ! -f "/usr/lib/firmware/amd/sof/sof-vangogh-data.bin" ] || \
           [ ! -f "/usr/lib/firmware/amd/sof/sof-vangogh-code.bin" ] || \
           [ ! -f "/usr/lib/firmware/amd/sof-tplg/sof-vangogh-nau8821-max.tplg" ]; then
            printf "%b\n" "${YELLOW}Note: Some OLED-specific firmware files may be missing. Install linux-firmware-neptune for full compatibility.${RC}"
        fi
    else
        printf "%b\n" "${YELLOW}Skipping Steam Deck specific firmware (not a Steam Deck)${RC}"
    fi
}

checkEnv
checkEscalationTool
detectSteamDeck
setUpRepos
installKernel
copyFirmwareFiles