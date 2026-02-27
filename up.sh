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

# Ensure the VirtualBox host-only network assigns 192.168.56.1 to the host.
# VirtualBox 7+ uses "hostonlynets" instead of legacy "hostonlyifs". Vagrant
# creates one named vagrantnet-vbox1 but defaults LowerIP to .3, making the
# host unreachable at the .1 address the Vagrantfile documents.
NET_NAME="vagrantnet-vbox1"
EXPECTED_LOWER="192.168.56.1"
CURRENT_LOWER=$(VBoxManage list hostonlynets 2>/dev/null \
  | awk '/^Name:/{name=$2} name=="'"$NET_NAME"'" && /^LowerIP:/{print $2; exit}')

if [ -z "$CURRENT_LOWER" ]; then
  echo "Creating host-only network ($NET_NAME) with host IP $EXPECTED_LOWER"
  VBoxManage hostonlynet add \
    --name="$NET_NAME" \
    --netmask=255.255.255.0 \
    --lower-ip="$EXPECTED_LOWER" \
    --upper-ip=192.168.56.254 \
    --enable
elif [ "$CURRENT_LOWER" != "$EXPECTED_LOWER" ]; then
  echo "Fixing host-only network: host IP $CURRENT_LOWER -> $EXPECTED_LOWER"
  VBoxManage hostonlynet modify \
    --name="$NET_NAME" \
    --lower-ip="$EXPECTED_LOWER"
fi

# Shared folder — uncomment and set to share a host directory with the VM:
# export SHARED_FOLDER="/path/to/your/project"

# Port forwarding — uncomment and list TCP ports to expose on localhost:
# export FORWARDED_PORTS="3000,8080,5173"

echo "Architecture: $VM_ARCH"
[ -n "$SHARED_FOLDER" ] && echo "Shared folder: $SHARED_FOLDER"

if vagrant status --machine-readable | grep -q "state,running"; then
  vagrant reload
else
  vagrant up
fi
