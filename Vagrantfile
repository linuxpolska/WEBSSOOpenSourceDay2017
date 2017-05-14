# -*- mode: ruby -*-
# vi: set ft=ruby :

# read vm and chef configurations from JSON files
nodes_config = (JSON.parse(File.read("nodes.json")))['nodes']

VAGRANTFILE_API_VERSION = "2"

def provisioned?(vm_name='default', provider='virtualbox')
  File.exist?(".vagrant/machines/#{vm_name}/#{provider}/action_provision")
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
    config.vbguest.no_install = true
  end
  if Vagrant.has_plugin?("vagrant-timezone")
    config.timezone.value = :host
  end
  nodes_config.each do |node|
    node_name   = node[0] # name of node
    node_values = node[1] # content of node

    config.vm.box = node_values[':box']

    config.hostmanager.enabled = true
    config.hostmanager.manage_host = true
    config.hostmanager.ignore_private_ip = false
    config.hostmanager.include_offline = true

    config.ssh.forward_x11 = true

    config.vm.define node_name do |config|
      # configures all forwarding ports in JSON array
      ports = node_values['ports']
      ports.each do |port|
        config.vm.network :forwarded_port,
          host:  port[':host'],
          guest: port[':guest'],
          id:    port[':id']
      end

      config.vm.hostname = node_name
      config.vm.network :private_network, ip: node_values[':ip']

      config.hostmanager.aliases = node_values[':alias'] if node_values[':alias']

      config.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", node_values[':memory']]
        vb.customize ["modifyvm", :id, "--name", node_name]
      end
      if Vagrant.has_plugin?("vagrant-persistent-storage") && node_values[':storage']
        config.persistent_storage.use_lvm = true
        config.persistent_storage.enabled = node_values[':storage']
        config.persistent_storage.location = "tmp/#{node[0]}.vdi"
        config.persistent_storage.size = node_values[':storage_size']
        config.persistent_storage.mountname = node_values[':storage_mountname']
        config.persistent_storage.volgroupname = node_values[':storage_volume']
        config.persistent_storage.filesystem = node_values[':storage_filesystem']
        config.persistent_storage.mountpoint = node_values[':storage_mntpoint']
      end
      config.vm.provision :shell, :path => "provision/bootstrap-rhel-enable-selinux-enforcment.sh"
      config.vm.provision :reload
      config.vm.provision :shell, :path => "provision/#{node[0]}.sh"
      if !node_values[':route_name'].nil?
        config.vm.provision :shell, :path => "provision/bootstrap-tomcat-route-config.sh", :args => node_values[':route_name']
      end
      config.vm.post_up_message = JSON.pretty_generate(node_values[':post_up_message']).gsub('[','').gsub(']','').gsub(/^$\n/, '')
    end
  end
end
