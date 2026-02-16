# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Define common settings
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_check_update = false

  # Database Server
  config.vm.define "db01" do |db|
    db.vm.hostname = "db01"
    db.vm.network "private_network", ip: "192.168.56.12"
    
    db.vm.provider "virtualbox" do |vb|
      vb.name = "db01"
      vb.memory = "1024"
      vb.cpus = 1
    end

    db.vm.provision "shell", path: "scripts/provision-db.sh"
  end

  # Application Server
  config.vm.define "app01" do |app|
    app.vm.hostname = "app01"
    app.vm.network "private_network", ip: "192.168.56.11"
    
    app.vm.provider "virtualbox" do |vb|
      vb.name = "app01"
      vb.memory = "1024"
      vb.cpus = 1
    end

    app.vm.provision "shell", path: "scripts/provision-app.sh"
  end

  # Web Server
  config.vm.define "web01" do |web|
    web.vm.hostname = "web01"
    web.vm.network "private_network", ip: "192.168.56.10"
    web.vm.network "forwarded_port", guest: 80, host: 8080
    
    web.vm.provider "virtualbox" do |vb|
      vb.name = "web01"
      vb.memory = "512"
      vb.cpus = 1
    end

    web.vm.provision "shell", path: "scripts/provision-web.sh"
  end
end