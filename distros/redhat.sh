#!/usr/bin/env bash
# distros/redhat.sh — Fedora, RHEL, CentOS, Rocky, Alma (dnf / yum)
# Part of GeoVirt Manager, by GeoKing
# Implements the distro contract: detect_pkg_manager, set_package_lists,
# is_installed, diagnose_and_fix_pkg_env, maybe_offer_backports,
# distro_clean_cache, distro_post_install_note.

detect_pkg_manager() {
    if command -v dnf &>/dev/null; then
        PKG_MANAGER="dnf"
        INSTALL_CMD=(dnf install -y); UPDATE_CMD=(dnf upgrade --refresh -y)
        REINSTALL_CMD=(dnf reinstall -y)
        REMOVE_CMD=(dnf remove -y); AUTOREMOVE_CMD=(dnf autoremove -y)
    elif command -v yum &>/dev/null; then
        PKG_MANAGER="yum"
        INSTALL_CMD=(yum install -y); UPDATE_CMD=(yum update -y)
        REINSTALL_CMD=(yum reinstall -y)
        REMOVE_CMD=(yum remove -y); AUTOREMOVE_CMD=(yum autoremove -y)
    else
        die "No supported package manager found (dnf, yum)."
    fi
    ok "Using package manager: ${PKG_MANAGER}"
}

# qemu.org points Fedora users at the "dnf install @virtualization" group,
# but we keep explicit packages here so install_pkgs' missing/present
# diffing and status_check both work per-package instead of per-group.
set_package_lists() {
    CORE_PKGS=(qemu-kvm libvirt libvirt-client virt-install virt-manager
               bridge-utils edk2-ovmf swtpm swtpm-tools)
    COCKPIT_PKGS=(cockpit cockpit-machines)
    SPICE_PKGS=(spice-vdagent spice-gtk3 virt-viewer qemu-img)
}

is_installed() {
    rpm -q "$1" &>/dev/null
}

diagnose_and_fix_pkg_env() {
    step "  -> Cleaning package metadata and retrying..."
    run soft "$PKG_MANAGER" clean all
    run soft "${UPDATE_CMD[@]}"
}

# No backports concept on the RHEL family — nothing to enable.
BACKPORTS_FLAG=()
maybe_offer_backports() { USE_BACKPORTS=0; BACKPORTS_FLAG=(); }

distro_clean_cache() {
    run soft "$PKG_MANAGER" clean all
}

distro_post_install_note() { :; }
