<img width="1536" height="1024" alt="Image" src="https://github.com/user-attachments/assets/5654a616-c37e-4ef7-a137-731c3b515c7a" />

# GeoVirt Manager

A simple self-healing installer and manager for **QEMU/KVM virtualization**, built by **GeoKing**.

It sets up **QEMU, KVM, libvirt, Cockpit, and SPICE**, configures the required services and groups, and can automatically fix common service issues in the background.

## Supported Systems

* **Debian:** Debian, Ubuntu and derivatives
* **RHEL:** Fedora, RHEL, CentOS, Rocky, Alma
* **Arch:** Arch Linux and derivatives
* **openSUSE:** Tumbleweed, Leap

The distro is detected automatically using `/etc/os-release`.

## Requirements

* Root/sudo access
* CPU with **Intel VT-x or AMD-V**
* Internet connection

## Installation

```bash
git clone https://github.com/aghaasfandyarkhan/QEMU-COCKPIT-INSTALLER.git
cd QEMU-COCKPIT-INSTALLER/geovirt
chmod +x geovirtualization-manager.sh
sudo ./geovirtualization-manager.sh
```

You'll get a simple menu:

```text
1) Install virtualization environment
2) Uninstall / remove components
3) Check current status
4) Run self-healing check
5) Install background watchdog
6) Remove watchdog
0) Exit
```

## What It Does

### Install

Choose between the full stack or individual components. The script installs the required packages, enables services, configures user groups, and checks that everything is working.

If a package installation fails, it retries the repair up to **3 times**.

### Uninstall

Remove selected components with confirmation. VM disks and libvirt configuration are kept unless you specifically choose to delete them.

### Status

Shows installed components, running services, and your current `libvirt`/`kvm` group membership.

### Self-Healing

Checks for common problems such as a missing `/dev/kvm` or stopped virtualization services, then attempts to fix them automatically.

### Watchdog

A systemd timer can run the same checks every **5 minutes**. If something keeps failing, it stops retrying after 5 consecutive failures instead of looping forever.

## Cockpit

If Cockpit is installed, open:

```text
https://localhost:9090
```

Log in with your normal Linux account.

## Logs

```text
/var/log/geovirt-manager.log
/var/lib/geovirt-manager/
```

If these locations aren't writable, the script falls back to `/tmp`.

## Project Structure

```text
geovirt/
├── geovirtualization-manager.sh
├── core/
│   ├── ui.sh
│   ├── heal.sh
│   ├── watchdog.sh
│   └── actions.sh
└── distros/
    ├── debian.sh
    ├── redhat.sh
    ├── arch.sh
    └── opensuse.sh
```

Each distro script handles its own package manager and package names. The rest of GeoVirt works the same way across supported distributions.

---

**GeoVirt Manager — by GeoKing**
