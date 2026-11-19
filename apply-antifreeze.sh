#!/usr/bin/env bash
# ==============================================================================
# System Resource Protection & Anti-Freeze Setup for Arch Linux / Hyprland
# Prevents system lockups, mouse cursor freezing, and OOM crashes under high load.
# ==============================================================================

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: This script must be run as root (use: sudo bash $0)" >&2
    exit 1
fi

echo "[*] Step 1: Installing earlyoom and verifying zram-generator..."
pacman -S --needed --noconfirm earlyoom zram-generator

echo "[*] Step 2: Deploying Kernel Memory Reserves & Sysctl Tunables..."
cat << 'EOF' > /etc/sysctl.d/99-anti-freeze.conf
# ==============================================================================
# ANTI-FREEZE & RESOURCE RESERVATION TUNABLES
# ==============================================================================

# Reserve 128 MiB exclusively for kernel atomic allocations (GFP_ATOMIC)
# Prevents NVIDIA proprietary driver NV_ERR_NO_MEMORY and dropped input events
vm.min_free_kbytes = 131072

# Wake up kswapd earlier (2% of zone) to proactively reclaim in the background
vm.watermark_scale_factor = 200

# Proactively compact memory in background to prevent contiguous allocation failures
vm.compaction_proactiveness = 50

# Aggressively compress anonymous heap into ZRAM before dropping desktop file caches
vm.swappiness = 180

# 4KB single-page transfers for ZRAM (eliminates read-ahead decompression latency)
vm.page-cluster = 0

# Prevent DRAM-less SSD writeback stalls: throttle dirty page spikes
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10

# Retain directory and inode caches on SSD
vm.vfs_cache_pressure = 50

# Single socket NUMA optimization
vm.zone_reclaim_mode = 0
EOF

sysctl --system > /dev/null

echo "[*] Step 3: Configuring High-Density 1.5x ZRAM Swap (zstd)..."
cat << 'EOF' > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram * 1.5
compression-algorithm = zstd
swap-priority = 32767
EOF

systemctl daemon-reload
# Restart zram swap safely
if swapoff /dev/zram0 2>/dev/null; then
    systemctl restart systemd-zram-setup@zram0.service || true
else
    systemctl restart systemd-zram-setup@zram0.service || true
fi

echo "[*] Step 4: Configuring EarlyOOM Daemon (Protecting Hyprland & Desktop)..."
cat << 'EOF' > /etc/default/earlyoom
EARLYOOM_ARGS="-m 4 -s 15 -r 60 --avoid '^(Hyprland|quickshell|Xwayland|wireplumber|pipewire.*|systemd.*|dbus.*|polkit.*|sshd|bash|zsh)$' --prefer '^(llama-server|python.*|ollama.*|cc1plus|rustc|Web Content|firefox|chromium|brave|electron)$' --sort-by-rss --syslog"
EOF

systemctl daemon-reload
systemctl enable --now earlyoom

echo "[*] Step 5: Elevating Compositor & Input Scheduler Limits..."
mkdir -p /etc/security/limits.d
cat << 'EOF' > /etc/security/limits.d/99-compositor-priority.conf
@wheel      hard    nice       -20
@wheel      soft    nice       -20
@wheel      hard    rtprio      95
@wheel      soft    rtprio      95
EOF

cat << 'EOF' > /usr/local/bin/hyprland-isolated
#!/bin/bash
if [ -w /proc/self/oom_score_adj ]; then
    echo -500 > /proc/self/oom_score_adj
fi
exec nice -n -15 /usr/bin/Hyprland "$@"
EOF
chmod +x /usr/local/bin/hyprland-isolated

echo ""
echo "=============================================================================="
echo " [✓] System Resource Protection Architecture successfully applied!"
echo "=============================================================================="
echo "Active ZRAM Status:"
zramctl
echo ""
echo "EarlyOOM Daemon Status:"
systemctl is-active earlyoom && echo "earlyoom is ACTIVE and monitoring memory every 100ms."
echo ""
echo "Key Sysctl Reserves:"
sysctl vm.min_free_kbytes vm.watermark_scale_factor vm.swappiness vm.dirty_ratio
echo "=============================================================================="
