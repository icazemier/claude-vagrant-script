#!/bin/sh
set -e

# Detect architecture
arch=$(uname -m)
case "$arch" in
  arm64|aarch64) VM_ARCH="arm64" ;;
  x86_64|amd64)  VM_ARCH="amd64" ;;
  *)             echo "Unsupported architecture: $arch"; exit 1 ;;
esac
export VM_ARCH

# Check prerequisites
command -v vagrant >/dev/null 2>&1 || { echo "Vagrant is not installed. Install from https://www.vagrantup.com/downloads"; exit 1; }
command -v VBoxManage >/dev/null 2>&1 || { echo "VirtualBox is not installed. Install from https://www.virtualbox.org/wiki/Downloads"; exit 1; }

# Pass through SHARED_FOLDER if set
# Usage: SHARED_FOLDER=/path/to/project ./up.sh

echo "Architecture: $VM_ARCH"
[ -n "$SHARED_FOLDER" ] && echo "Shared folder: $SHARED_FOLDER"

vagrant up
