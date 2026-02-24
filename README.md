# Claude Dev VM

A pre-configured Ubuntu 24.04 LTS virtual machine with Claude Code and claude-flow, using Vagrant + VirtualBox.

## What's Included

- **Ubuntu 24.04 LTS** (auto-detects ARM64 or AMD64)
- **XFCE4** lightweight desktop with auto-login
- **nvm** (Node Version Manager) with **Node.js 22** as default
- **Claude Code** (`@anthropic-ai/claude-code`)
- **claude-flow** orchestrator (`claude-flow@alpha`)
- **Chromium** and **Firefox** browsers
- **Playwright** with Chromium (for browser automation)
- **Display auto-resize** when scaling the VirtualBox window (ARM workaround included)
- **SSH** server enabled
- Build essentials, git, curl, wget, vim

## How It Works

This project uses two tools to create and manage a virtual machine on your computer:

**VirtualBox** is the software that actually runs the virtual machine. Think of it as a "computer inside your computer" — it creates an isolated Linux environment with its own desktop, files, and software. The VM window that pops up is a full Ubuntu desktop running inside VirtualBox.

**Vagrant** is a command-line tool that automates VirtualBox. Without Vagrant, you'd have to manually create a VM, download an OS image, click through the installer, and then run dozens of setup commands. Vagrant does all of that for you in a single command. It reads a configuration file (`Vagrantfile`) that describes what kind of VM to create, and a provisioning script (`provision.sh`) that lists what software to install inside it.

### What happens when you run `./up.sh`

```
./up.sh runs
  → Detects your CPU architecture (ARM64 or AMD64)
  → Checks that VirtualBox and Vagrant are installed
  → Calls `vagrant up`, which:
      → Downloads a base Ubuntu 24.04 image (a "box") if not cached yet
      → Creates a new VirtualBox VM from that image
      → Runs provision.sh inside the VM to install everything
      → Opens the VirtualBox window with the XFCE desktop
  → Done — fully configured VM with Claude Code ready to use
```

The base image download only happens once. Vagrant caches it locally, so future `vagrant up` commands skip that step and start much faster.

### The files in this project

| File | Purpose |
|---|---|
| `up.sh` | Entry point. Detects your architecture, checks prerequisites, runs `vagrant up` |
| `Vagrantfile` | Tells Vagrant how to configure the VM: what base image to use, how much RAM/CPU, shared folders, etc. Think of it as the VM's blueprint |
| `provision.sh` | Runs inside the VM on first boot. Installs all the software: Node.js, Claude Code, the desktop environment, browsers, etc. |

## First-Time Setup

Follow these steps in order. This only needs to be done once.

### 1. Install VirtualBox and Vagrant

You need two things on your host machine (your Mac or PC):

1. **VirtualBox 7.1+** — the VM engine that runs the virtual machine
2. **Vagrant 2.4+** — the command-line tool that automates VirtualBox

**macOS (Homebrew):**

```bash
brew install --cask virtualbox vagrant
```

If you don't have Homebrew, install it first from [brew.sh](https://brew.sh/).

**Linux (Debian/Ubuntu):**

```bash
sudo apt-get update
sudo apt-get install -y virtualbox vagrant
```

Your distribution's package may be outdated. If you run into issues, install the latest versions from the official download pages instead.

**Manual download (any platform):**

- VirtualBox: [virtualbox.org/wiki/Downloads](https://www.virtualbox.org/wiki/Downloads)
- Vagrant: [vagrantup.com/downloads](https://www.vagrantup.com/downloads)

**Optional — vagrant-vbguest plugin:**

This plugin manages VirtualBox Guest Additions (drivers that improve display resolution, clipboard sharing, and shared folders) inside the VM:

```bash
vagrant plugin install vagrant-vbguest
```

Note: version 0.32.0 of this plugin has a bug with Ruby 3.2+ that causes a `File.exists?` error. The Vagrantfile disables auto-update to work around this. If you need to update Guest Additions manually, run `vagrant vbguest` after the VM is up.

### 2. Create the VM

```bash
./up.sh
```

Or, if you want to share a project folder with the VM (so Claude Code can work on your files):

```bash
SHARED_FOLDER=~/myproject ./up.sh
```

This will take a while on the first run — Vagrant needs to download the base Ubuntu image (~1-2 GB) and then install all the software inside the VM. You'll see a lot of terminal output as packages are installed. This is normal.

When it's done, a VirtualBox window will appear showing the Ubuntu XFCE desktop. The `claude` user is logged in automatically.

### 3. Authenticate Claude Code

Inside the VM, open a terminal (there's a "Claude Terminal" shortcut on the desktop) and run:

```bash
claude
```

You have two authentication options:

- **Claude.ai subscription** — `claude` will prompt you to log in via the browser (no API key needed)
- **API key** — if you prefer, set it first:
  ```bash
  export ANTHROPIC_API_KEY=your-key-here
  claude
  ```
  To make the API key permanent:
  ```bash
  echo 'export ANTHROPIC_API_KEY=your-key-here' >> ~/.bashrc
  ```

### 4. Verify

Inside the VM, check that everything was installed:

```bash
nvm --version           # nvm (Node Version Manager)
node --version          # Should show v22.x
claude --version        # Claude Code
claude-flow --version   # claude-flow
```

To switch Node.js versions (e.g. for testing against an older release):

```bash
nvm install 20          # Install Node.js 20
nvm use 20              # Switch to it
nvm use default         # Switch back to 22
```

That's it — you're ready to use Claude Code inside the VM.

## Architecture Support

`up.sh` auto-detects your CPU architecture via `uname -m` and picks the right VM image:

| Your machine | Detected as | VM image |
|---|---|---|
| Apple Silicon Mac (M1/M2/M3/M4) | `arm64` | `bento/ubuntu-24.04` arm64 variant |
| Intel Mac or Linux/Windows PC | `amd64` | `bento/ubuntu-24.04` amd64 variant |

You normally don't need to think about this. If you do need to override it:

```bash
VM_ARCH=amd64 vagrant up
```

## Shared Folder

A shared folder lets the VM access a directory on your host machine. This is the bridge between your normal development environment and the VM.

Set the `SHARED_FOLDER` environment variable when creating the VM:

```bash
SHARED_FOLDER=/path/to/project ./up.sh
```

Inside the VM, your files appear at:

```
/home/claude/shared
```

### Why a shared folder?

- **Use your host IDE/editor** — edit files on your Mac, let Claude Code in the VM handle execution, builds, and tests
- **No git credentials needed** inside the VM — your host handles git
- **No friction** getting files in and out of the VM

### Security model

The **VM itself is the sandbox**. The guest OS is completely isolated from your host — it cannot see any host files outside the shared folder, cannot access your home directory or SSH keys, and cannot touch host processes. Even if something goes wrong inside the VM, the blast radius is limited to that one shared folder.

Within the shared folder, mount options provide defense-in-depth:

| Mount option | What it does |
|---|---|
| `dmode=775` | Directory permissions: owner/group can read-write-execute, others can only read |
| `fmode=664` | File permissions: owner/group can read-write, others can only read |

If the shared folder is already mounted, `provision.sh` remounts it with `nodev,nosuid` to block device file tricks and privilege escalation via setuid binaries.

## Connecting to Host Services

The VM uses a private network so it can reach services running on your host machine (like MongoDB, Redis, or any other server).

| Machine | IP address |
|---|---|
| Host (your Mac/PC) | `192.168.56.1` |
| VM (guest) | `192.168.56.10` |

To verify connectivity, run this inside the VM:

```bash
ping 192.168.56.1
```

### Key requirement: bind to the right interface

By default, most services only listen on `127.0.0.1` (localhost), which means they only accept connections from the same machine. For the VM to connect, the service must listen on `192.168.56.1` or `0.0.0.0` (all interfaces).

**MongoDB** — edit `/usr/local/etc/mongod.conf` (macOS Homebrew) or `/etc/mongod.conf` (Linux):

```yaml
net:
  bindIp: 0.0.0.0
```

Then restart: `brew services restart mongodb-community` (macOS) or `sudo systemctl restart mongod` (Linux).

**Redis** — edit `/usr/local/etc/redis.conf` (macOS Homebrew) or `/etc/redis/redis.conf` (Linux):

```
bind 0.0.0.0
```

Then restart: `brew services restart redis` (macOS) or `sudo systemctl restart redis` (Linux).

**macOS firewall** — if you have the firewall enabled (System Settings → Network → Firewall), make sure incoming connections are allowed for the service, or add an exception.

### Using host services from inside the VM

Point your application at `192.168.56.1` instead of `localhost`. For example:

```bash
# MongoDB
mongodb://192.168.56.1:27017/mydb

# Redis
redis://192.168.56.1:6379
```

## VM Management

After the initial setup, you manage the VM with Vagrant commands. Run these from your **host machine** (not inside the VM), in the same directory as the `Vagrantfile`:

```bash
vagrant halt        # Shut down the VM (like powering off a computer)
vagrant up          # Start the VM again (fast — no re-provisioning)
vagrant reload      # Restart the VM (halt + up)
vagrant destroy     # Delete the VM entirely (re-run ./up.sh to recreate from scratch)
vagrant provision   # Re-run provision.sh without recreating the VM (useful after editing provision.sh)
vagrant ssh         # SSH into the VM (auto-switches to claude user)
```

### Lifecycle summary

```
./up.sh ──→ VM created and provisioned (first time)
              │
              ▼
         VM is running ◄──── vagrant up (starts a stopped VM)
              │
         vagrant halt ──→ VM is stopped (state preserved on disk)
              │
         vagrant destroy ──→ VM is deleted (start over with ./up.sh)
```

## Customization

### Provisioned software

Edit `provision.sh` to change what gets installed. For example, add a line like `apt-get install -y htop` to install additional packages. After editing, apply your changes to an existing VM with:

```bash
vagrant provision
```

### VM resources

Edit the `Vagrantfile` to adjust RAM, CPUs, or other VirtualBox settings:

```ruby
vb.memory = 8192   # 8 GB RAM (default: 4096)
vb.cpus = 4        # 4 CPU cores (default: 2)
```

Then reload to apply:

```bash
vagrant reload
```

## Troubleshooting

### vagrant-vbguest `File.exists?` crash

If you see an error like `undefined method 'exists?' for class File`, this is a known bug in vagrant-vbguest 0.32.0 with Ruby 3.2+. The Vagrantfile already works around this by disabling auto-update. If you still hit it, you can uninstall the plugin entirely:

```bash
vagrant plugin uninstall vagrant-vbguest
```

### Guest Additions issues

"Guest Additions" are VirtualBox drivers that run inside the VM to enable features like shared folders, clipboard sharing, and automatic display resizing. If any of these aren't working, install the vagrant-vbguest plugin and run it manually:

```bash
vagrant plugin install vagrant-vbguest
vagrant up         # if the VM isn't running
vagrant vbguest    # manually install/update Guest Additions
vagrant reload
```

### ARM64: no matching box found

Not all Vagrant boxes support ARM64. The `bento/ubuntu-24.04` box supports both architectures. Make sure you're using VirtualBox 7.1+ which added ARM64 support.

### Shared folder not appearing

1. Make sure `SHARED_FOLDER` points to an existing directory on your host
2. The variable must be set when running `vagrant up` (not just `vagrant reload`)
3. Check inside the VM: `mount | grep shared`

### Desktop doesn't appear

The XFCE desktop should auto-login and appear immediately after provisioning. If you see a text console instead, the graphical target may not have started. Try:

```bash
vagrant ssh -c 'sudo systemctl start lightdm'
```

If that doesn't help, reboot:

```bash
vagrant reload
```

### Display doesn't resize with VirtualBox window

On ARM (Apple Silicon), VBoxClient doesn't auto-apply resize hints. The VM includes a workaround service (`vbox-autoresize`) that polls for resolution changes and applies them. Check that it's running:

```bash
vagrant ssh -c 'systemctl status vbox-autoresize'
```

If it's not running, start it:

```bash
vagrant ssh -c 'sudo systemctl start vbox-autoresize'
```

### Can't connect to host services from VM

If your app inside the VM can't reach a service on the host (e.g. `EHOSTUNREACH` or `Connection refused`):

1. **Check the service is listening on the right interface.** Run on the host:
   ```bash
   # macOS
   lsof -iTCP:27017 -sTCP:LISTEN
   # Linux
   ss -tlnp | grep 27017
   ```
   If it shows `127.0.0.1:27017`, the service is only accepting local connections. Change its bind address to `0.0.0.0` (see [Connecting to Host Services](#connecting-to-host-services) above).

2. **Check connectivity from inside the VM:**
   ```bash
   ping 192.168.56.1
   ```

3. **If ping fails**, the host-only network may not exist. On the host, check:
   ```bash
   VBoxManage list hostonlyifs
   ```
   You should see a `vboxnet0` interface with IP `192.168.56.1`. If it's missing, run `vagrant reload` to recreate the network.

4. **After changing Vagrantfile networking**, always run `vagrant reload` to apply the changes.

### npm packages not installed

All npm packages are installed via nvm for the `claude` user. To reinstall manually, SSH in and run:

```bash
vagrant ssh
source ~/.nvm/nvm.sh
npm install -g @anthropic-ai/claude-code claude-flow@alpha playwright
npx playwright install chromium
```
