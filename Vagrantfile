# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "net9/ubuntu-24.04-arm64"
  config.vm.box_version = "1.1"

  # Disable automatic box update checking
  config.vm.box_check_update = false
  
  # 부팅 타임아웃(커스텀 ISO 등 느린 환경 대비)
  # config.vm.boot_timeout = 1200
  
  # 기본 공유 폴더 비활성화
  config.vm.synced_folder "./", "/vagrant", disabled: true

  # vagrant-disksize 플러그인 사용
  if Vagrant.has_plugin?("vagrant-disksize")
    config.disksize.size = "50GB"
  end
  
  # vagrant-vbguest 플러그인 사용 시 자동 업데이트 비활성화
  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
  end
  
  # Master node
  config.vm.define "k8s-master" do |master|
    master.vm.hostname = "k8s-master"
    master.vm.network "private_network", ip: "192.168.127.128", netmask: "255.255.255.0"
    master.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
      vb.cpus = 4
      vb.name = "k8s-master"
      
      # 아래는 vagrant-disksize 플러그인 도입 전 수동 디스크 생성 코드 (주석처리)
      # # SATA 컨트롤러 추가
      # vb.customize ['storagectl', :id, '--name', 'SATA', '--add', 'sata', '--controller', 'IntelAHCI']
      # # Boot from ISO
      # vb.customize ['storageattach', :id, '--storagectl', 'IDE', '--port', 0, '--device', 0, '--type', 'dvddrive', '--medium', './ubuntu-24.04.2-live-server-arm64.iso']
      # # Create main disk (50GB) - dynamically allocated
      # main_disk_path = "k8s-master-main.vdi"
      # unless File.exist?(main_disk_path)
      #   vb.customize ['createhd', '--filename', main_disk_path, '--size', 50 * 1024, '--variant', 'Standard']
      # end
      # vb.customize ['storageattach', :id, '--storagectl', 'SATA', '--port', 0, '--device', 0, '--type', 'hdd', '--medium', main_disk_path]
    end
    master.vm.provision "shell", inline: <<-SHELL
      # Set up vagrant user
      usermod -aG sudo vagrant
      echo 'vagrant ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
    SHELL
  end

  # Worker nodes
  (1..3).each do |i|
    config.vm.define "k8s-worker#{i}" do |worker|
      worker.vm.hostname = "k8s-worker#{i}"
      worker.vm.network "private_network", ip: "192.168.127.#{128 + i}", netmask: "255.255.255.0"
      
      # Set disk size. Worker 3 gets 100GB, others get 50GB.
      worker.disksize.size = (i == 3) ? '100GB' : '50GB'

      worker.vm.provider "virtualbox" do |vb|
        vb.memory = "2048"
        vb.cpus = 2
        vb.name = "k8s-worker#{i}"
        
        # 아래는 vagrant-disksize 플러그인 도입 전 수동 디스크 생성 코드 (주석처리)
        # # SATA 컨트롤러 추가
        # vb.customize ['storagectl', :id, '--name', 'SATA', '--add', 'sata', '--controller', 'IntelAHCI']
        # # Boot from ISO
        # vb.customize ['storageattach', :id, '--storagectl', 'IDE', '--port', 0, '--device', 0, '--type', 'dvddrive', '--medium', './ubuntu-24.04.2-live-server-arm64.iso']
        # # Create main disk - worker3 gets 100GB, others get 50GB
        # disk_size = i == 3 ? 100 : 50
        # main_disk_path = "k8s-worker#{i}-main.vdi"
        # unless File.exist?(main_disk_path)
        #   vb.customize ['createhd', '--filename', main_disk_path, '--size', disk_size * 1024, '--variant', 'Standard']
        # end
        # vb.customize ['storageattach', :id, '--storagectl', 'SATA', '--port', 0, '--device', 0, '--type', 'hdd', '--medium', main_disk_path]
      end
      worker.vm.provision "shell", inline: <<-SHELL
        # Set up vagrant user
        usermod -aG sudo vagrant
        echo 'vagrant ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
      SHELL
    end
  end
end
