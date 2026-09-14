#!/usr/bin/env bash
# core/actions.sh — install / uninstall / status orchestration
# Part of GeoVirt Manager, by GeoKing
# Requires: core/ui.sh, core/heal.sh sourced first, and a distros/*.sh sourced
# so PKG_MANAGER, the command arrays, package lists, is_installed(),
# maybe_offer_backports() and diagnose_and_fix_pkg_env() all exist.

target_user() { echo "${SUDO_USER:-$USER}"; }

open_cockpit_firewall_port() {
    command -v firewall-cmd &>/dev/null || return 0
    systemctl is-active --quiet firewalld || return 0
    step "  -> firewalld detected, opening Cockpit port (9090/tcp)..."
    run soft firewall-cmd --add-service=cockpit --permanent
    run soft firewall-cmd --reload
    ok "Cockpit port opened through firewalld"
}

# Install / reinstall a package set, with self-healing retries.
# use_backports=1 pins apt to <codename>-backports (debian family only —
# other distros' maybe_offer_backports() leaves this at 0).
install_pkgs() {
    local use_backports="$1"; shift
    local -a pkgs=("$@")
    ((${#pkgs[@]})) || return 0

    local -a missing=() present=()
    for pkg in "${pkgs[@]}"; do
        if is_installed "$pkg"; then present+=("$pkg"); else missing+=("$pkg"); fi
    done

    local -a extra=()
    [[ "$use_backports" -eq 1 ]] && extra=("${BACKPORTS_FLAG[@]}")

    if ((${#missing[@]})); then
        step "  -> Installing: ${missing[*]}"
        run_retrying hard "${INSTALL_CMD[@]}" "${extra[@]}" "${missing[@]}"
    fi

    if ((${#present[@]})); then
        step "  -> Already present, refreshing: ${present[*]}"
        if [[ "$PKG_MANAGER" == "aptitude" ]]; then
            for pkg in "${present[@]}"; do run_retrying soft "${REINSTALL_CMD[@]}" "$pkg"; done
        else
            run_retrying soft "${REINSTALL_CMD[@]}" "${extra[@]}" "${present[@]}"
        fi
    fi
}

# Component selection, shared by install and uninstall
WITH_CORE=0; WITH_COCKPIT=0; WITH_SPICE=0

choose_components() {
    echo
    msg "$C_BOLD" "Which components would you like to work with?"
    echo "  1) Full stack: core virtualization + Cockpit + SPICE tools (recommended)"
    echo "  2) Core virtualization only (QEMU/KVM, libvirt, virt-manager)"
    echo "  3) Core virtualization + Cockpit web console"
    echo "  4) Core virtualization + SPICE guest tools"
    echo "  0) Back to main menu"
    echo
    read -r -p "Select an option [0-4]: " comp_choice

    WITH_CORE=1; WITH_COCKPIT=0; WITH_SPICE=0
    case "$comp_choice" in
        1) WITH_COCKPIT=1; WITH_SPICE=1 ;;
        2) : ;;
        3) WITH_COCKPIT=1 ;;
        4) WITH_SPICE=1 ;;
        0) return 1 ;;
        *) fail "Invalid choice."; return 1 ;;
    esac
    return 0
}

install_environment() {
    set_package_lists
    choose_components || return 0

    banner
    msg "$C_BOLD" "Installing selected components on ${DISTRO_NAME}"
    echo

    step "[1/6] Updating package index..."
    run_retrying hard "${UPDATE_CMD[@]}"

    USE_BACKPORTS=0
    if [[ "$WITH_COCKPIT" -eq 1 ]]; then
        maybe_offer_backports
    fi

    step "[2/6] Installing packages..."
    [[ "$WITH_CORE" -eq 1 ]]    && install_pkgs 0 "${CORE_PKGS[@]}"
    [[ "$WITH_SPICE" -eq 1 ]]   && install_pkgs 0 "${SPICE_PKGS[@]}"
    [[ "$WITH_COCKPIT" -eq 1 ]] && install_pkgs "$USE_BACKPORTS" "${COCKPIT_PKGS[@]}"

    step "[3/6] Enabling services..."
    run hard systemctl enable --now libvirtd
    if [[ "$WITH_COCKPIT" -eq 1 ]]; then
        run hard systemctl enable --now cockpit.socket
        open_cockpit_firewall_port
    fi

    step "[4/6] Adding your user account to the virtualization groups..."
    local user; user="$(target_user)"
    run soft usermod -aG libvirt "$user"
    run soft usermod -aG kvm "$user"

    step "[5/6] Checking hardware and service status (with auto-repair)..."
    heal_kvm_module
    check_virtualization_support
    heal_service libvirtd
    systemctl is-active --quiet libvirtd \
        && ok "libvirtd is running" \
        || fail "libvirtd did not start; check: systemctl status libvirtd"
    if [[ "$WITH_COCKPIT" -eq 1 ]]; then
        heal_service cockpit.socket
        systemctl is-active --quiet cockpit.socket \
            && ok "cockpit.socket is active" \
            || fail "cockpit.socket did not start; check: systemctl status cockpit.socket"
    fi
    command -v spice-vdagent &>/dev/null && ok "SPICE tools installed on host"

    step "[6/6] Done."
    echo
    msg "$C_GREEN" "=============================================================="
    msg "$C_GREEN" "                  INSTALLATION COMPLETE"
    msg "$C_GREEN" "=============================================================="
    echo
    msg "$C_BOLD" "Next steps:"
    echo "  1. Log out and back in (or reboot) so the libvirt/kvm group membership takes effect."
    echo "  2. Launch virt-manager from your app menu or a terminal to create VMs."
    if [[ "$WITH_COCKPIT" -eq 1 ]]; then
        echo "  3. Manage VMs from a browser:"
        msg "$C_CYAN" "         https://localhost:9090"
        echo "     Log in with your normal Linux credentials; use the host IP for remote access."
        distro_post_install_note 2>/dev/null || true
    fi
    echo "  4. Set each VM's display to SPICE and enable clipboard/drag-and-drop in its settings."
    echo "  5. Inside each guest, install 'spice-vdagent' (Linux) or 'spice-guest-tools' (Windows)."
    echo "  6. Consider option 5 in the main menu to install the self-healing watchdog."
    echo
    msg "$C_CYAN" "  GeoVirt Manager — by GeoKing"
    echo
}

uninstall_environment() {
    set_package_lists
    choose_components || return 0

    local -a selected=()
    [[ "$WITH_CORE" -eq 1 ]]    && selected+=("${CORE_PKGS[@]}")
    [[ "$WITH_COCKPIT" -eq 1 ]] && selected+=("${COCKPIT_PKGS[@]}")
    [[ "$WITH_SPICE" -eq 1 ]]   && selected+=("${SPICE_PKGS[@]}")

    banner
    msg "$C_RED" "About to remove the following from ${DISTRO_NAME}:"
    echo "  ${selected[*]}"
    echo
    warn "This also stops related services and drops your user from the libvirt/kvm groups."
    confirm "Type y to confirm" || { fail "Uninstall cancelled."; return 0; }

    local wipe_data="n"
    if confirm "Also delete VM configs/disks metadata under /var/lib/libvirt and /etc/libvirt?"; then
        wipe_data="y"
    fi

    step "[1/6] Removing the self-healing watchdog, if present..."
    if systemctl list-unit-files 2>/dev/null | grep -q '^geovirt-selfheal.timer'; then
        remove_watchdog
    fi

    step "[2/6] Stopping services..."
    run soft systemctl stop libvirtd cockpit.socket
    run soft systemctl disable libvirtd cockpit.socket

    step "[3/6] Removing packages..."
    run soft "${REMOVE_CMD[@]}" "${selected[@]}"
    run soft "${AUTOREMOVE_CMD[@]}"

    if [[ "$wipe_data" == "y" ]]; then
        step "[4/6] Removing configuration and stored data..."
        run soft rm -rf /etc/libvirt /var/lib/libvirt /etc/cockpit /var/lib/cockpit
        run soft rm -rf /var/log/libvirt /var/log/cockpit
    else
        step "[4/6] Keeping configuration and VM data as requested."
    fi

    step "[5/6] Removing your user from virtualization groups..."
    local user; user="$(target_user)"
    run soft gpasswd -d "$user" libvirt
    run soft gpasswd -d "$user" kvm

    step "[6/6] Cleaning package manager cache..."
    distro_clean_cache

    echo
    msg "$C_GREEN" "=============================================================="
    msg "$C_GREEN" "                   UNINSTALL COMPLETE"
    msg "$C_GREEN" "=============================================================="
    warn "A reboot is recommended to fully clear any loaded kernel modules."
}

status_check() {
    set_package_lists
    banner
    msg "$C_BOLD" "Current status on ${DISTRO_NAME}"
    echo

    step "Hardware:"
    check_virtualization_support
    echo

    step "Packages:"
    for pkg in "${CORE_PKGS[@]}" "${COCKPIT_PKGS[@]}" "${SPICE_PKGS[@]}"; do
        is_installed "$pkg" && ok "$pkg is installed" || warn "$pkg is not installed"
    done
    echo

    step "Services:"
    if systemctl list-unit-files 2>/dev/null | grep -q '^libvirtd'; then
        systemctl is-active --quiet libvirtd \
            && ok "libvirtd is running" || warn "libvirtd is installed but not running"
    else
        warn "libvirtd service not found"
    fi
    if systemctl list-unit-files 2>/dev/null | grep -q '^cockpit.socket'; then
        systemctl is-active --quiet cockpit.socket \
            && ok "cockpit.socket is active" || warn "cockpit.socket is installed but not active"
    else
        warn "cockpit.socket not found"
    fi
    if systemctl list-unit-files 2>/dev/null | grep -q '^geovirt-selfheal.timer'; then
        systemctl is-active --quiet geovirt-selfheal.timer \
            && ok "self-healing watchdog is active" || warn "self-healing watchdog is installed but inactive"
    else
        warn "self-healing watchdog is not installed"
    fi
    echo

    local user; user="$(target_user)"
    step "Group membership for ${user}:"
    id -nG "$user" | grep -qw libvirt && ok "member of libvirt group" || warn "not in libvirt group"
    id -nG "$user" | grep -qw kvm     && ok "member of kvm group"     || warn "not in kvm group"
    echo
}
