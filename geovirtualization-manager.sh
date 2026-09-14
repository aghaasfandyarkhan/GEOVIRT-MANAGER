#!/usr/bin/env bash
#
# GeoVirt Manager — with self-healing
# QEMU/KVM + libvirt + SPICE + Cockpit — install / uninstall / status / heal
# Developed by GeoKing
#
# Supports:
#   Debian family   : Debian, Ubuntu and derivatives   (apt / nala / aptitude)
#   RHEL family     : Fedora, RHEL, CentOS, Rocky, Alma (dnf / yum)
#   Arch family     : Arch Linux and derivatives        (pacman)
#   openSUSE family : Tumbleweed / Leap                 (zypper)
#
set -uo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
LOG_FILE="/var/log/geovirt-manager.log"
STATE_DIR="/var/lib/geovirt-manager"
MAX_INSTALL_RETRIES=3
MAX_HEAL_ATTEMPTS=5

# shellcheck source=core/ui.sh
source "${SCRIPT_DIR}/core/ui.sh"

trap 'echo; warn "Interrupted."; exit 130' INT TERM

# ------------------------------------------------------------------------------
# Root check
[[ $EUID -eq 0 ]] || die "This script must be run as root. Try: sudo $SCRIPT_NAME"
: >"$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/geovirt-manager.log"
mkdir -p "$STATE_DIR" 2>/dev/null || STATE_DIR="/tmp/geovirt-manager"

# shellcheck source=core/heal.sh
source "${SCRIPT_DIR}/core/heal.sh"
# shellcheck source=core/watchdog.sh
source "${SCRIPT_DIR}/core/watchdog.sh"
# shellcheck source=core/actions.sh
source "${SCRIPT_DIR}/core/actions.sh"

# ------------------------------------------------------------------------------
# Distro + package manager detection

DISTRO_FAMILY=""
DISTRO_NAME=""
DISTRO_ID=""
DISTRO_CODENAME=""
PKG_MANAGER=""
declare -a INSTALL_CMD UPDATE_CMD REINSTALL_CMD REMOVE_CMD AUTOREMOVE_CMD

detect_distro() {
    [[ -f /etc/os-release ]] || die "/etc/os-release not found; cannot detect distribution."
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_NAME="${PRETTY_NAME:-$ID}"
    DISTRO_ID="${ID:-}"
    DISTRO_CODENAME="${VERSION_CODENAME:-}"
    local id_string="${ID:-} ${ID_LIKE:-}"

    case "$id_string" in
        *debian*|*ubuntu*)   DISTRO_FAMILY="debian" ;;
        *rhel*|*fedora*|*centos*) DISTRO_FAMILY="redhat" ;;
        *arch*)              DISTRO_FAMILY="arch" ;;
        *suse*)              DISTRO_FAMILY="opensuse" ;;
        *) die "Unsupported distribution: ${DISTRO_NAME}. Supported families: Debian/Ubuntu, RHEL/Fedora, Arch, openSUSE." ;;
    esac

    local distro_file="${SCRIPT_DIR}/distros/${DISTRO_FAMILY}.sh"
    [[ -f "$distro_file" ]] || die "Missing distro module: $distro_file"
    # shellcheck disable=SC1090
    source "$distro_file"

    ok "Detected: ${DISTRO_NAME} (${DISTRO_FAMILY} family)"
}

# ------------------------------------------------------------------------------
# --heal : non-interactive entry point for the systemd watchdog timer
if [[ "${1:-}" == "--heal" ]]; then
    detect_distro
    run_self_heal
    exit 0
fi

# ------------------------------------------------------------------------------
# MAIN MENU (loop, not recursion — avoids stack growth on repeated use)

main_menu() {
    local choice again
    while true; do
        banner
        echo "  1) Install virtualization environment"
        echo "  2) Uninstall / remove components"
        echo "  3) Check current status"
        echo "  4) Run self-healing check & repair now"
        echo "  5) Install background self-healing watchdog (every 5 min)"
        echo "  6) Remove self-healing watchdog"
        echo "  0) Exit"
        echo
        read -r -p "Select an option [0-6]: " choice

        case "$choice" in
            1) detect_pkg_manager; install_environment ;;
            2) detect_pkg_manager; uninstall_environment ;;
            3) status_check ;;
            4) run_self_heal ;;
            5) install_watchdog ;;
            6) remove_watchdog ;;
            0) msg "$C_GREEN" "Goodbye. — GeoVirt Manager, by GeoKing"; exit 0 ;;
            *) fail "Invalid option." ;;
        esac

        echo
        read -r -p "Return to main menu? [y/N]: " again
        [[ "$again" =~ ^[Yy]$ ]] || exit 0
    done
}

# ------------------------------------------------------------------------------
# Entry point
detect_distro
main_menu
