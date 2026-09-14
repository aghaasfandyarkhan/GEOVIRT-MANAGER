#!/usr/bin/env bash
# core/heal.sh — retries, service healing, hardware checks
# Part of GeoVirt Manager, by GeoKing
# Requires: core/ui.sh sourced first. Uses globals LOG_FILE, STATE_DIR,
# MAX_INSTALL_RETRIES, MAX_HEAL_ATTEMPTS set by the entrypoint.
# Calls diagnose_and_fix_pkg_env() — defined per-distro in distros/*.sh.

# Safe command runner.
#   run hard <cmd...>  -> abort the script if it fails
#   run soft <cmd...>  -> warn and continue if it fails
run() {
    local mode="$1"; shift
    log "RUN: $*"
    if "$@" >>"$LOG_FILE" 2>&1; then
        return 0
    fi
    local rc=$?
    if [[ "$mode" == "hard" ]]; then
        die "Command failed: $* (details in $LOG_FILE)" "$rc"
    fi
    warn "Command failed, continuing: $* (details in $LOG_FILE)"
    return "$rc"
}

# Retry wrapper: run_retrying <hard|soft> <cmd...>
# Runs the command; on failure, diagnoses + repairs the package environment
# (via the distro-specific diagnose_and_fix_pkg_env), backs off, and retries
# up to MAX_INSTALL_RETRIES times.
run_retrying() {
    local mode="$1"; shift
    local -a cmd=("$@")
    local attempt=0

    while true; do
        run soft "${cmd[@]}" && return 0
        attempt=$((attempt + 1))
        if (( attempt >= MAX_INSTALL_RETRIES )); then
            if [[ "$mode" == "hard" ]]; then
                die "Command failed after ${MAX_INSTALL_RETRIES} attempts: ${cmd[*]} (see $LOG_FILE)"
            fi
            warn "Giving up after ${MAX_INSTALL_RETRIES} attempts: ${cmd[*]}"
            return 1
        fi
        warn "Attempt ${attempt}/${MAX_INSTALL_RETRIES} failed; running self-repair before retry..."
        diagnose_and_fix_pkg_env
        sleep $((attempt * 3))
    done
}

heal_kvm_module() {
    [[ -e /dev/kvm ]] && return 0
    warn "/dev/kvm missing, attempting to load the KVM kernel module..."
    grep -q vmx /proc/cpuinfo 2>/dev/null && run soft modprobe kvm_intel
    grep -q svm /proc/cpuinfo 2>/dev/null && run soft modprobe kvm_amd
    if [[ -e /dev/kvm ]]; then
        ok "/dev/kvm is now present after modprobe"
    else
        warn "/dev/kvm still missing; check that virtualization is enabled in BIOS/UEFI."
    fi
}

check_virtualization_support() {
    if grep -Eq '(vmx|svm)' /proc/cpuinfo 2>/dev/null; then
        ok "CPU reports hardware virtualization support (VT-x / AMD-V)"
    else
        warn "No vmx/svm flag in /proc/cpuinfo. Enable virtualization in BIOS/UEFI."
    fi
    if [[ -e /dev/kvm ]]; then
        ok "/dev/kvm is present"
    else
        warn "/dev/kvm not found. KVM acceleration won't work until it appears."
    fi
}

# heal_service <unit>: restarts a down service, tracking consecutive
# failures in $STATE_DIR so it stops retrying after MAX_HEAL_ATTEMPTS.
heal_service() {
    local svc="$1"
    systemctl list-unit-files 2>/dev/null | grep -q "^${svc}" || return 0

    local counter_file="${STATE_DIR}/${svc}.failcount"
    if systemctl is-active --quiet "$svc"; then
        rm -f "$counter_file"
        return 0
    fi

    local fails=0
    [[ -f "$counter_file" ]] && fails="$(<"$counter_file")"
    if (( fails >= MAX_HEAL_ATTEMPTS )); then
        warn "${svc} has failed ${fails} recovery attempts; not retrying automatically. Check: systemctl status ${svc}"
        return 1
    fi

    warn "${svc} is down, attempting recovery (attempt $((fails + 1))/${MAX_HEAL_ATTEMPTS})..."
    run soft systemctl reset-failed "$svc"
    run soft systemctl restart "$svc"
    sleep 2

    if systemctl is-active --quiet "$svc"; then
        ok "${svc} recovered"
        rm -f "$counter_file"
    else
        fails=$((fails + 1))
        echo "$fails" >"$counter_file"
        fail "${svc} still down after restart (attempt ${fails}/${MAX_HEAL_ATTEMPTS})"
    fi
}

run_self_heal() {
    step "Running self-healing checks..."
    heal_kvm_module
    heal_service libvirtd
    heal_service cockpit.socket
    heal_service virtlogd
    ok "Self-heal pass complete."
}
