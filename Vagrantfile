Vagrant.configure("2") do |config|
  vm_arch = ENV["VM_ARCH"] || "amd64"
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.box_architecture = vm_arch
  config.vm.hostname = "claude-dev"

  config.vm.provider "virtualbox" do |vb|
    vb.gui = true
    vb.name = "Claude Dev VM"
    vb.memory = 4096
    vb.cpus = 2
    vb.customize ["modifyvm", :id, "--vram", "128"]
    vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
    vb.customize ["modifyvm", :id, "--accelerate3d", "off"]
    vb.customize ["modifyvm", :id, "--clipboard-mode", "bidirectional"]
    vb.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
  end

  # Disable vagrant-vbguest auto-update to avoid File.exists? crash
  # in plugin v0.32.0 with Ruby 3.2+. Run `vagrant vbguest` manually
  # if you need to update Guest Additions.
  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
  end

  config.vm.synced_folder ".", "/vagrant", disabled: true

  shared_folder = ENV["SHARED_FOLDER"]
  if shared_folder && !shared_folder.empty? && Dir.exist?(shared_folder)
    config.vm.synced_folder shared_folder, "/home/claude/shared",
      owner: 1001, group: 1001,
      mount_options: ["dmode=775,fmode=664"]
  end

  config.vm.provision "shell", path: "provision.sh", privileged: true
end
