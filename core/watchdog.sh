#!/usr/bin/env bash
# core/watchdog.sh — background self-heal timer
# Part of GeoVirt Manager, by GeoKing
# Requires: core/ui.sh sourced first. Uses globals SCRIPT_PATH, LOG_FILE.

install_watchdog() {
    step "Installing background self-healing watchdog (systemd timer, every 5 min)..."
    cat >/etc/systemd/system/geovirt-selfheal.service <<UNIT_EOF
[Unit]
Description=GeoVirt Manager self-healing check for QEMU/KVM, libvirt and Cockpit (by GeoKing)

[Service]
Type=oneshot
ExecStart=${SCRIPT_PATH} --heal
UNIT_EOF

    cat >/etc/systemd/system/geovirt-selfheal.timer <<TIMER_EOF
[Unit]
Description=Run GeoVirt Manager self-heal periodically (by GeoKing)

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
TIMER_EOF

    run hard systemctl daemon-reload
    run hard systemctl enable --now geovirt-selfheal.timer
    ok "Watchdog installed. It will restart crashed services and re-check /dev/kvm every 5 minutes."
    echo "  Logs: $LOG_FILE"
    echo "  Inspect timer: systemctl list-timers geovirt-selfheal.timer"
}

remove_watchdog() {
    step "Removing self-healing watchdog..."
    run soft systemctl disable --now geovirt-selfheal.timer
    run soft rm -f /etc/systemd/system/geovirt-selfheal.timer /etc/systemd/system/geovirt-selfheal.service
    run soft systemctl daemon-reload
    ok "Watchdog removed."
}
