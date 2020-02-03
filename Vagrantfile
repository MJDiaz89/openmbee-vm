Vagrant.configure("2") do |config|

  config.vm.box = "bento/centos-7.5"

  config.vm.network "forwarded_port", guest: 8080, host: 8080

  config.vm.provider "virtualbox" do |vb|
    vb.name = "MMS VE Server"
    vb.cpus = 4
    vb.memory = 12288  # Solr requires a lot of RAM
    vb.gui = false
  end

  config.vm.provision "shell", path: "provision.sh"

  config.vm.post_up_message = "OpenMBEE MMS Virtual Machine has been successfully created.

    Login to View Editor:
    ---------------------
    You can login to the View Editor by going to:

    http://127.0.0.1:8080/alfresco/mmsapp/mms.html#/login

    and the values of MMS_USERNAME and MMS_PASSWORD in the .env file to log in. The default is `admin` for both.

    Troubleshoot:
    -------------
    If that URL is missing, make sure Alfresco is running, by going to:

    http://127.0.0.1:8080/alfresco

    If that is not working, checkout the container logs by:

    1. SSH'ing into the VM: `vagrant ssh`
    2. Make sure the services are running: `dc ps`
    3. And inspecting the logs: `dc logs`

    Note:
    -----
    This VM contains some custom commands and aliases to help experienced users.  To see these commands
    ssh into the VM, and type `commands`.

    Important Notice:
    -----------------
    For this server to be useful, you will need to have: MagicDraw, the the MagicDraw Model Development Kit
    (MDK) plugin, and a SysML model.

    As of Feb 4, 2019, the latest MDK plugin version for MagicDraw is 4.0.0 and can be found here:

    https://bintray.com/openmbee/maven/mdk/

    You can check the compatibility matrix between MMS and MDK here:

    https://github.com/Open-MBEE/open-mbee.github.io/blob/master/compat%20matrix.pdf

  "

end