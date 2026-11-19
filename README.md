# Anti-Freeze

A system resource-protection setup script for **Arch Linux with Hyprland**. It configures early OOM handling, zram swap, memory-management tunables, and compositor scheduling priorities to help keep a desktop responsive during memory pressure.

> **Caution:** This script makes system-wide changes as root. It installs packages and overwrites several configuration files under `/etc`, and creates `/usr/local/bin/hyprland-isolated`. Review `apply-antifreeze.sh` before running it, and back up any existing files it will replace. These settings are workload- and hardware-dependent; they cannot guarantee that a system will never freeze.

## What it changes

- Installs `earlyoom` and `zram-generator` with `pacman`.
- Writes `/etc/sysctl.d/99-anti-freeze.conf` with memory, reclaim, compaction, swap, and dirty-page settings. This includes reserving 128 MiB for kernel allocations.
- Writes `/etc/systemd/zram-generator.conf` to configure a zstd-compressed zram device sized to 1.5 times RAM, with high swap priority.
- Configures and enables `earlyoom`, with arguments intended to protect core desktop/system processes and prefer terminating selected memory-heavy workloads.
- Writes `/etc/security/limits.d/99-compositor-priority.conf` to grant members of the `wheel` group scheduling limits.
- Creates `/usr/local/bin/hyprland-isolated`, a Hyprland launcher that adjusts the process OOM score and nice level.

The script applies the sysctl settings and reloads systemd configuration. It does **not** configure your display manager or session to launch Hyprland through `hyprland-isolated`; select that launcher in your session configuration if you want to use it.

## Requirements

- Arch Linux (or a closely compatible system using `pacman` and systemd)
- Hyprland
- Root access
- The `wheel` group, if you intend to use the configured scheduling limits

## Install

Clone or download this repository, inspect the script, then run it as root:

```bash
sudo bash apply-antifreeze.sh
```

The script requires root privileges and uses `pacman` to install the required packages. Reboot after applying the configuration so all system and session-level changes take effect consistently.

## Verify

The script prints zram, earlyoom, and selected sysctl status at the end. You can also check them later with:

```bash
zramctl
systemctl status earlyoom
sysctl vm.min_free_kbytes vm.watermark_scale_factor vm.swappiness vm.dirty_ratio
```

To use the isolated launcher directly, run:

```bash
hyprland-isolated
```

Do not start a second compositor from inside an existing Hyprland session.

## Reverting changes

The script does not create backups or provide an automatic uninstall. Before running it, save any existing files it may replace. To revert, remove the files created by the script and restore your backups, then reload the relevant services or reboot:

- `/etc/sysctl.d/99-anti-freeze.conf`
- `/etc/systemd/zram-generator.conf` (restore your previous file if one existed)
- `/etc/default/earlyoom` (restore your previous file if one existed)
- `/etc/security/limits.d/99-compositor-priority.conf`
- `/usr/local/bin/hyprland-isolated`

If you no longer want the installed services or packages, disable `earlyoom` and remove packages only after checking whether anything else on your system depends on them. Removing these files alone does not undo package installation.

## Disclaimer

This is a set of system-tuning choices, not a universal fix. Test it on your own system, keep recovery access available, and adjust or revert settings if they cause unexpected behavior.
