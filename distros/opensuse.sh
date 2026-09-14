#!/usr/bin/env bash
# distros/opensuse.sh — openSUSE Tumbleweed / Leap (zypper)
# Part of GeoVirt Manager, by GeoKing
# Implements the distro contract: detect_pkg_manager, set_package_lists,
# is_installed, diagnose_and_fix_pkg_env, maybe_offer_backports,
# distro_clean_cache, distro_post_install_note.

detect_pkg_manager() {
    command -v zypper &>/dev/null || die "No supported package manager found (zypper)."
    PKG_MANAGER="zypper"
    INSTALL_CMD=(zypper --non-interactive install)
    UPDATE_CMD=(zypper --non-interactive refresh)
    REINSTALL_CMD=(zypper --non-interactive install --force)
    REMOVE_CMD=(zypper --non-interactive remove --clean-deps)
    AUTOREMOVE_CMD=(zypper --non-interactive packages --orphaned)
    ok "Using package manager: ${PKG_MANAGER}"
}

# qemu-spice is what cockpit-machines actually requires on SUSE (per its
# own spec file) rather than a plain qemu-utils equivalent.
set_package_lists() {
    CORE_PKGS=(qemu-kvm libvirt libvirt-client virt-install virt-manager
               bridge-utils qemu-ovmf-x86_64 swtpm)
    COCKPIT_PKGS=(cockpit cockpit-machines)
    SPICE_PKGS=(spice-vdagent spice-gtk virt-viewer qemu-spice)
}

is_installed() {
    rpm -q "$1" &>/dev/null
}

diagnose_and_fix_pkg_env() {
    step "  -> Forcing a full repository refresh..."
    run soft zypper --non-interactive refresh --force
}

# No backports concept on openSUSE — nothing to enable.
BACKPORTS_FLAG=()
maybe_offer_backports() { USE_BACKPORTS=0; BACKPORTS_FLAG=(); }

distro_clean_cache() {
    run soft zypper clean --all
}

# Cockpit disallows root login by default on openSUSE (see
# /etc/cockpit/disallowed-users) — unlike Debian/RHEL/Arch where root can
# log in out of the box. Surface this so it isn't a silent login failure.
distro_post_install_note() {
    warn "openSUSE disallows root login to Cockpit by default."
    echo "     To allow it: edit /etc/cockpit/disallowed-users and remove the 'root' line."
}
