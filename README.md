# VM for OpenMBEE MMS

A vagrant-based virtual machine (VM) for setting up the 
* [Open Model Based Engineering Environment (OpenMBEE)][openmbee]
* [Model Management System (MMS)][mms] 
* [View Editor (VE)][view-editor]
stack that is part of [OpenMBEE Docker stack][docker-image].

In addition, this stack also sets up
* [pgAdmin, a Postgres database browser][pgadmin]
* [Dejavu, an ElasticSearch browser][dejavu]
* [Apache Jena Fuseki, a SPARQL server][fuseki]
as additional tools to help browse the data within MMS.

> This virtual machine was developed to facilitate the installation of the OpenMBEE MMS server.
It is intended as a stop-gap solution until a scalable containerized version of the OpenMBEE MMS server can be developed, e.g., using [Kubernetes][kubernetes].

As of Feb 4, 2020, this VM works with [OpenMBEE MMS Docker Image][docker-image] v3.4.2 (latest) and [View Editor (VE)][view-editor] v3.6.1 (latest).  Additionally, the [Model Development Kit (MDK)][mdk] v4.1.3 (latest) plugin for [MagicDraw][magicdraw] successfully works with the MMS server this repo provisions.  Other MMS and VE versions have not been tested.  

This VM has been successfully deployed and tested in a local Ubuntu 18.04 server, as well as a Windows 10 computer.


## Prerequisites
Applicable to all operating systems:

1. Install [Vagrant][vagrant].

2. Install [VirtualBox][virtualbox].


## Installation
1. Clone this repository:
    ```
    git clone https://github.com/MJDiaz89/openmbee-vm.git
    ```

2. Provision the virtual machine:
    ```
    cd openmbee-vm
    vagrant up
    ```

> The first time you run this, it will take some time to start all the services, so please be patient.

## Usage

### Login to Alfresco
    http://127.0.0.1:8080/share/page/
using `admin` as both the username and the password.

### Login to View Editor
You can login to the OpenMBEE [View Editor][view-editor] by going to:

    http://127.0.0.1:8080/ve/mms.html#/login

and using `admin` as both the username and the password.

### Login to PG Admin
You can browse the Postgres database by going to

    http://127.0.0.1:5433

Authenticate with `pgadmin4@pgadmin.org` as the user and `admin` as the password.

### Login to Dejavu
You can browse the ElasticSearch database through Dejavu by going to

    http://127.0.0.1:1358

Enter `http://127.0.0.1:9200` in the page's cluster URL; the app name is the ElasticSearch index you want to browse, i.e. use `<project id>` (in lower case) to view a specific project or `*` to browse all.

### Using Apache Jena Fuseki
This repo only sets up the [Fuseki][fuseki] remote server on http://127.0.0.1:13030.  In order to use Fuseki and MMS, visit https://github.com/Open-MBEE/mms-rdf for instructions.  Those instructions should be ran on the host machine running the Vagrant VM (not the Vagrant VM itself) using all `local` commands.  

#### Other useful links
See everything Tomcat is running :

    http://127.0.0.1:8080/manager/html/


See MMS's full API and SDK documentation:

    http://127.0.0.1:8080/alfresco/mms/index.html


### Access REST API
You can access the Swagger UI at

    http://127.0.0.1:8080/alfresco/mms/swagger-ui/index.html


### Test MMS via REST 
Use the following curl commands to post an initial organization + project:
```
curl -w "\n%{http_code}\n" -H "Content-Type: application/json" -u admin:admin --data '{"orgs": [{"id": "vetestorg", "name": "vetestorg"}]}' -X POST "http://localhost:8080/alfresco/service/orgs"
curl -w "\n%{http_code}\n" -H "Content-Type: application/json" -u admin:admin --data '{"projects": [{"id": "vetestproj","name": "vetestproj","orgId": "vetestorg", "type": "Project"}]}' -X POST "http://localhost:8080/alfresco/service/orgs/vetestorg/projects"
```

Make sure the server accepted them:
````
curl -w "\n%{http_code}\n" -H "Content-Type: application/json" -u admin:admin -X GET "http://localhost:8080/alfresco/service/orgs"
curl -w "\n%{http_code}\n" -H "Content-Type: application/json" -u admin:admin -X GET "http://localhost:8080/alfresco/service/orgs/vetestorg/projects"
````


### Troubleshoot
If that URL is not responding, make sure [Alfresco][alfresco] is running, by going to:

    http://127.0.0.1:8080/alfresco

If that is not working, checkout the `docker-compose` logs by:

1. SSH'ing into the VM:

    ```
    vagrant ssh
    ```

2. And inspecting the logs:

    ```
    docker-compose -f /vagrant/docker-compose.yml --project-directory /vagrant logs
    ```
    
    Alternatively, a user can use the `dc` alias command:
    
    ```
    dc logs
    ``` 
    
    or

    ```
    dc logs --follow --tail 0
    ```

    to inspect how the server is handeling requests and responses.

3. Make sure the docker containers are actually running:
    ```
    dc ps
    ```

    For more information on the custom commands, type:
    
    ```
    commands
    ``` 

4. Make sure you can access Tomcat at
   ```
   http://127.0.0.1:8080
   ```
   and that you see all services running at
   ```
   http://127.0.0.1:8080/manager/html/list
   ```
   authenticate with 
   ```
   user: admin
   password: tomcatadmin
   ```

### Important Notice
To maximize the server's usefulness, you will need to have: [MagicDraw][magicdraw], the
[Model Development Kit (MDK)][mdk] plugin, and a SysML model.

As of Jan 24, 2020, the latest MDK plugin version for MagicDraw is 4.1.3 and can be found here:

    https://bintray.com/openmbee/maven/mdk/4.1.3

**Note:** do not let MDK create an organization for you!  Otherwise, you may end up with an unstable organization.  Instead, create it with the curl command above.


[alfresco]: https://www.alfresco.com/ "Alfresco"
[docker-image]: https://hub.docker.com/r/openmbeeguest/mms-repo/ "OpenMBEE Docker Image"
[kubernetes]: https://kubernetes.io/ "Kubernetes"
[magicdraw]: https://www.nomagic.com/products/magicdraw "MagicDraw"
[mdk]: https://github.com/Open-MBEE/mdk "Model Development Kit"
[mms]: https://github.com/Open-MBEE/mms "Model Management System"
[openmbee]: http://www.openmbee.org/ "OpenMBEE"
[vagrant]: https://www.vagrantup.com/downloads.html "Vagrant"
[view-editor]: https://github.com/Open-MBEE/ve "View Editor"
[virtualbox]: https://www.virtualbox.org/wiki/Downloads "VirtualBox"
[pgadmin]: https://www.pgadmin.org/ "pgAdmin"
[dejavu]: https://opensource.appbase.io/dejavu/ "Dejavu"
[fuseki]: https://jena.apache.org/documentation/fuseki2/ "fuseki"