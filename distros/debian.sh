#!/usr/bin/env bash
# distros/debian.sh — Debian, Ubuntu and derivatives (apt / nala / aptitude)
# Part of GeoVirt Manager, by GeoKing
# Implements the distro contract: detect_pkg_manager, set_package_lists,
# is_installed, diagnose_and_fix_pkg_env, maybe_offer_backports,
# distro_clean_cache, distro_post_install_note.

detect_pkg_manager() {
    if command -v nala &>/dev/null; then
        PKG_MANAGER="nala"
        INSTALL_CMD=(nala install -y); UPDATE_CMD=(nala update)
        REINSTALL_CMD=(nala install --install-recommends --install-suggests -y)
        REMOVE_CMD=(nala purge --autoremove -y); AUTOREMOVE_CMD=(nala autopurge -y)
    elif command -v apt-get &>/dev/null; then
        PKG_MANAGER="apt"
        INSTALL_CMD=(apt-get install -y); UPDATE_CMD=(apt-get update)
        REINSTALL_CMD=(apt-get install --reinstall -y)
        REMOVE_CMD=(apt-get remove --purge -y); AUTOREMOVE_CMD=(apt-get autoremove --purge -y)
    elif command -v aptitude &>/dev/null; then
        PKG_MANAGER="aptitude"
        INSTALL_CMD=(aptitude install -y); UPDATE_CMD=(aptitude update)
        REINSTALL_CMD=(aptitude reinstall -y)
        REMOVE_CMD=(aptitude remove --purge -y); AUTOREMOVE_CMD=(aptitude purge -y)
    else
        die "No supported package manager found (nala, apt, aptitude)."
    fi
    ok "Using package manager: ${PKG_MANAGER}"
}

# Package lists (2026 baselines). swtpm/OVMF because current guests
# (Windows 11+, many modern Linux ISOs) expect UEFI + TPM 2.0 by default.
# qemu-system is the upstream-recommended full-emulation package.
set_package_lists() {
    CORE_PKGS=(qemu-system libvirt-daemon-system libvirt-clients bridge-utils
               virt-manager virtinst cpu-checker virtiofsd ovmf swtpm swtpm-tools)
    COCKPIT_PKGS=(cockpit cockpit-machines)
    SPICE_PKGS=(spice-vdagent spice-client-gtk virt-viewer qemu-utils spice-webdavd)
}

is_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "^install ok installed"
}

diagnose_and_fix_pkg_env() {
    if [[ -e /var/lib/dpkg/lock-frontend ]] && ! fuser /var/lib/dpkg/lock-frontend &>/dev/null; then
        step "  -> Stale dpkg lock with no active holder, repairing state..."
        run soft dpkg --configure -a
    fi
    step "  -> Attempting to fix broken dependencies..."
    run soft apt-get -f install -y
    run soft "${UPDATE_CMD[@]}"
}

# Debian/Ubuntu stable repos commonly ship a stale cockpit-machines.
# Cockpit upstream (cockpit-project.org) itself recommends installing
# from backports on Debian and Ubuntu — offer to enable it.
BACKPORTS_FLAG=()
maybe_offer_backports() {
    USE_BACKPORTS=0
    [[ -n "$DISTRO_CODENAME" ]] || return 0

    local list_file="/etc/apt/sources.list.d/${DISTRO_CODENAME}-backports.list"
    if [[ -f "$list_file" ]] || grep -Rq "${DISTRO_CODENAME}-backports" \
        /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null; then
        USE_BACKPORTS=1
    else
        confirm "  Enable ${DISTRO_CODENAME}-backports for a newer Cockpit?" || return 0
        local mirror="http://deb.debian.org/debian"
        local suite="${DISTRO_CODENAME}-backports main"
        if [[ "$DISTRO_ID" == "ubuntu" ]]; then
            mirror="http://archive.ubuntu.com/ubuntu"
            suite="${DISTRO_CODENAME}-backports main universe"
        fi
        echo "deb ${mirror} ${suite}" >"$list_file"
        run soft "${UPDATE_CMD[@]}"
        USE_BACKPORTS=1
        ok "Backports enabled for ${DISTRO_CODENAME}."
    fi

    if [[ "$USE_BACKPORTS" -eq 1 && "$PKG_MANAGER" != "aptitude" ]]; then
        BACKPORTS_FLAG=(-t "${DISTRO_CODENAME}-backports")
    else
        BACKPORTS_FLAG=()
    fi
}

distro_clean_cache() {
    case "$PKG_MANAGER" in
        nala)     run soft nala clean ;;
        aptitude) run soft aptitude clean ;;
        apt)      run soft apt-get clean ;;
    esac
}

distro_post_install_note() { :; }
