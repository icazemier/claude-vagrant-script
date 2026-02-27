#!/bin/bash
# migrate.sh — Apply provision.sh improvements to existing VMs
#
# Usage:  vagrant ssh -c "sudo bash /vagrant/migrate.sh"
#   or:   copy into VM and run as root
#
# Safe to run multiple times (all steps are idempotent).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: must run as root (use sudo)" >&2
  exit 1
fi

echo "─── Migration: applying provision.sh improvements ───"

# ─── 1. Remove snapd (saves ~5 GB) ──────────────────────────
if command -v snap &>/dev/null; then
  echo "[1/7] Removing snapd..."
  snap list --all | awk '/^[a-z]/ && !/^Name/ {print $1}' | while read -r pkg; do
    snap remove --purge "$pkg" 2>/dev/null || true
  done
  systemctl stop snapd.socket snapd.service 2>/dev/null || true
  apt-get autopurge -y snapd
  rm -rf /snap /var/snap /var/lib/snapd /root/snap /home/*/snap
else
  echo "[1/7] snapd already removed, skipping."
fi

# Prevent snapd from being pulled back in
if [ ! -f /etc/apt/preferences.d/no-snapd ]; then
  cat > /etc/apt/preferences.d/no-snapd << 'PREF'
Package: snapd
Pin: release *
Pin-Priority: -1
PREF
fi

# ─── 2. Extend LV to use full disk ──────────────────────────
if command -v lvextend &>/dev/null; then
  FREE=$(vgdisplay --units m 2>/dev/null | awk '/Free  PE/ {print int($NF)}')
  if [ "${FREE:-0}" -gt 0 ]; then
    echo "[2/7] Extending LV to use full disk (${FREE}M free)..."
    lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv 2>/dev/null || true
    resize2fs /dev/ubuntu-vg/ubuntu-lv 2>/dev/null || true
  else
    echo "[2/7] LV already uses full disk, skipping."
  fi
else
  echo "[2/7] LVM not available, skipping."
fi

# ─── 3. Remove chromium-browser and firefox ──────────────────
REMOVED_BROWSER=false
for pkg in chromium-browser firefox; do
  if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
    if [ "$REMOVED_BROWSER" = false ]; then
      echo "[3/7] Removing unused browsers..."
      REMOVED_BROWSER=true
    fi
    apt-get autopurge -y "$pkg"
  fi
done
if [ "$REMOVED_BROWSER" = false ]; then
  echo "[3/7] No unused browsers found, skipping."
fi

# ─── 4. Strip XFCE to bare minimum ──────────────────────────
# The xfce4 + xfce4-goodies meta-packages pull in ~40 GUI apps
# and panel plugins that are never used. Keep only the core desktop.
XFCE_BLOAT=(
  xfce4-goodies
  xfce4
  mousepad ristretto xfburn xfce4-dict xfce4-screenshooter
  xfce4-taskmanager thunar-archive-plugin thunar-media-tags-plugin
  tumbler xfce4-appfinder xterm
)
INSTALLED_BLOAT=()
for pkg in "${XFCE_BLOAT[@]}"; do
  if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
    INSTALLED_BLOAT+=("$pkg")
  fi
done
if [ ${#INSTALLED_BLOAT[@]} -gt 0 ]; then
  echo "[4/7] Stripping XFCE to bare minimum (removing ${#INSTALLED_BLOAT[@]} packages)..."
  # Mark the packages we want to keep as manually installed
  apt-mark manual xfwm4 xfce4-panel xfce4-session xfce4-settings \
    xfdesktop4 xfce4-terminal xfconf thunar 2>/dev/null || true
  apt-get autopurge -y "${INSTALLED_BLOAT[@]}"
else
  echo "[4/7] XFCE already minimal, skipping."
fi

# ─── 5. Install yarn via npm ────────────────────────────────
if su - claude -c 'source ~/.nvm/nvm.sh && command -v yarn' &>/dev/null; then
  echo "[5/7] yarn already installed, skipping."
else
  echo "[5/7] Installing yarn..."
  su - claude -c 'source ~/.nvm/nvm.sh && npm install -g yarn'
fi

# ─── 6. Set up UFW firewall ─────────────────────────────────
if ufw status 2>/dev/null | grep -q "Status: active"; then
  # Ensure NAT gateway rule exists (needed for forwarded ports)
  if ! ufw status | grep -q "10.0.2.0/24"; then
    echo "[6/7] Adding UFW rule for NAT gateway (forwarded ports)..."
    ufw allow from 10.0.2.0/24
  else
    echo "[6/7] UFW already configured, skipping."
  fi
else
  echo "[6/7] Setting up UFW firewall..."
  apt-get install -y ufw

  ufw default deny incoming
  ufw default allow outgoing

  # Allow SSH from anywhere (required for vagrant ssh)
  ufw allow 22/tcp

  # Allow all traffic from the host-only network
  ufw allow from 192.168.56.0/24

  # Allow all traffic from VirtualBox NAT gateway (for forwarded ports)
  ufw allow from 10.0.2.0/24

  # Enable firewall (--force to avoid interactive prompt)
  ufw --force enable
fi

# ─── 7. Clean up caches ─────────────────────────────────────
echo "[7/7] Cleaning caches..."
apt-get clean
rm -rf /var/lib/apt/lists/*
su - claude -c 'source ~/.nvm/nvm.sh && npm cache clean --force && yarn cache clean' 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Migration complete!                                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
