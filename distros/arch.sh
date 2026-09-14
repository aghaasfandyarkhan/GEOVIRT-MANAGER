#!/usr/bin/env bash
# distros/arch.sh — Arch Linux and derivatives (pacman)
# Part of GeoVirt Manager, by GeoKing
# Implements the distro contract: detect_pkg_manager, set_package_lists,
# is_installed, diagnose_and_fix_pkg_env, maybe_offer_backports,
# distro_clean_cache, distro_post_install_note.

detect_pkg_manager() {
    command -v pacman &>/dev/null || die "No supported package manager found (pacman)."
    PKG_MANAGER="pacman"
    INSTALL_CMD=(pacman -S --noconfirm --needed)
    UPDATE_CMD=(pacman -Sy --noconfirm)
    REINSTALL_CMD=(pacman -S --noconfirm)
    REMOVE_CMD=(pacman -Rns --noconfirm)
    AUTOREMOVE_CMD=(bash -c 'orphans=$(pacman -Qtdq 2>/dev/null); [[ -n "$orphans" ]] && pacman -Rns --noconfirm $orphans || true')
    ok "Using package manager: ${PKG_MANAGER}"
}

# dnsmasq (NAT DHCP) and iptables-nft (libvirt's default NAT backend on
# Arch) are Arch-specific needs the Debian/RHEL lists don't carry.
set_package_lists() {
    CORE_PKGS=(qemu-full libvirt virt-install virt-manager bridge-utils
               edk2-ovmf swtpm dnsmasq iptables-nft)
    COCKPIT_PKGS=(cockpit cockpit-machines)
    SPICE_PKGS=(spice-vdagent spice-gtk virt-viewer)
}

is_installed() {
    pacman -Qi "$1" &>/dev/null
}

diagnose_and_fix_pkg_env() {
    if [[ -e /var/lib/pacman/db.lck ]] && ! fuser /var/lib/pacman/db.lck &>/dev/null; then
        step "  -> Stale pacman db lock with no active holder, removing..."
        run soft rm -f /var/lib/pacman/db.lck
    fi
    step "  -> Forcing a full database refresh..."
    run soft pacman -Syy --noconfirm
}

# No backports concept on Arch (rolling release) — nothing to enable.
BACKPORTS_FLAG=()
maybe_offer_backports() { USE_BACKPORTS=0; BACKPORTS_FLAG=(); }

distro_clean_cache() {
    run soft pacman -Sc --noconfirm
}

distro_post_install_note() { :; }
