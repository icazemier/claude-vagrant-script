#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ─── Create claude user ──────────────────────────────────────
if ! id claude &>/dev/null; then
  useradd -m -u 1001 -s /bin/bash claude
  echo "claude:claude" | chpasswd
  usermod -aG sudo claude
  echo "claude ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/claude
  chmod 440 /etc/sudoers.d/claude
fi

# ─── Update packages ─────────────────────────────────────────
apt-get update
apt-get upgrade -y

# ─── Install apt packages ────────────────────────────────────
apt-get install -y \
  build-essential \
  git \
  curl \
  wget \
  vim \
  openssh-server \
  ca-certificates \
  gnupg \
  xfce4 \
  xfce4-goodies \
  lightdm \
  lightdm-gtk-greeter \
  chromium-browser \
  firefox \
  xterm

# ─── Install nvm and Node.js 22 for claude user ──────────────
su - claude -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash'
su - claude -c 'source ~/.nvm/nvm.sh && nvm install 22 && nvm alias default 22'

# ─── Install npm globals (as claude, via nvm) ────────────────
su - claude -c 'source ~/.nvm/nvm.sh && npm install -g @anthropic-ai/claude-code'
su - claude -c 'source ~/.nvm/nvm.sh && npm install -g claude-flow@alpha'
su - claude -c 'source ~/.nvm/nvm.sh && npm install -g playwright'

# Playwright browser deps need apt (root), then install browser as claude
npx() { su - claude -c "source ~/.nvm/nvm.sh && npx $*"; }
apt-get install -y libnss3 libatk-bridge2.0-0 libdrm2 libxcomposite1 \
  libxdamage1 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libasound2t64 \
  libxshmfence1 libx11-xcb1 2>/dev/null || true
su - claude -c 'source ~/.nvm/nvm.sh && npx playwright install chromium'

# ─── Enable services ─────────────────────────────────────────
systemctl enable ssh
systemctl start ssh
systemctl enable lightdm
systemctl set-default graphical.target

# ─── Configure LightDM auto-login ────────────────────────────
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf << 'EOF'
[Seat:*]
autologin-user=claude
autologin-user-timeout=0
EOF

# ─── Set up shared folder ────────────────────────────────────
mkdir -p /home/claude/shared
chown claude:claude /home/claude/shared

# Remount with nodev,nosuid if the shared folder is already mounted
if mountpoint -q /home/claude/shared; then
  mount -o remount,nodev,nosuid /home/claude/shared
fi

# ─── Welcome message in .bashrc ──────────────────────────────
cat >> /home/claude/.bashrc << 'BASHRC'

# ─── Claude Dev Environment ───────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Welcome to the Claude Dev VM!                          ║"
echo "║                                                         ║"
echo "║  To get started, run: claude                            ║"
echo "║                                                         ║"
echo "║  Authentication options:                                 ║"
echo "║    1. Claude.ai subscription — claude will prompt you   ║"
echo "║       to log in via the browser on first run            ║"
echo "║    2. API key — export ANTHROPIC_API_KEY=your-key       ║"
echo "║                                                         ║"
echo "║  Available tools:                                       ║"
echo "║    nvm            Node version manager                  ║"
echo "║    claude         Claude Code                           ║"
echo "║    claude-flow    claude-flow orchestrator               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
BASHRC
chown claude:claude /home/claude/.bashrc

# ─── Desktop terminal shortcut ───────────────────────────────
mkdir -p /home/claude/Desktop
cat > /home/claude/Desktop/claude-terminal.desktop << 'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=Claude Terminal
Comment=Open terminal for Claude Code
Exec=xfce4-terminal
Icon=utilities-terminal
Terminal=false
Categories=System;TerminalEmulator;
DESKTOP
chmod +x /home/claude/Desktop/claude-terminal.desktop
chown -R claude:claude /home/claude/Desktop

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Provisioning complete!                                  ║"
echo "║  Log in as: claude / claude                              ║"
echo "║  Run 'claude' to authenticate and get started            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
