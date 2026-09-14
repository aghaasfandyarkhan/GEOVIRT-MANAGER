#!/usr/bin/env bash
# core/ui.sh — messaging, banner, confirm prompts
# Part of GeoVirt Manager, by GeoKing

if [[ -t 1 ]]; then
    C_RED=$'\033[1;31m'; C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'
    C_BLUE=$'\033[1;34m'; C_CYAN=$'\033[1;36m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""; C_BOLD=""; C_RESET=""
fi

log()   { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG_FILE" 2>/dev/null || true; }
msg()   { printf '%s%s%s\n' "$1" "$2" "$C_RESET"; log "$2"; }
ok()    { msg "$C_GREEN"  "  [OK]   $1"; }
fail()  { msg "$C_RED"    "  [FAIL] $1"; }
warn()  { msg "$C_YELLOW" "  [WARN] $1"; }
step()  { msg "$C_CYAN"   "$1"; }
die()   { fail "$1"; exit "${2:-1}"; }

confirm() {
    local reply
    read -r -p "$1 [y/N]: " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

banner() {
    clear
    msg "$C_BLUE" "=============================================================="
    msg "$C_BOLD"  "          GEOVIRT MANAGER (Self-Healing)"
    msg "$C_CYAN"  "         QEMU/KVM  -  libvirt  -  SPICE  -  Cockpit"
    msg "$C_BLUE" "=============================================================="
    msg "$C_CYAN"  "                 developed by GeoKing"
    echo
}
