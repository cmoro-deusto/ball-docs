Server Installation and Configuration
=================================
This documents describes the steps required to build the Bolala infrastructure servers from the ground up. It's based on the following asumptions:

- Amazon Web Services as IaaS Platform
- Server package installation using APT and NPM
- Server management scripts using Upstart
- Automated deployments using a script leveraging Git
- Example git repository and installation directories have been used. Change them to the appropriate values.


## Instance Installation
### Installation Process Overview
The instance creation process is divided in seven simple steps that can be performed directly from within the **AWS Administration Console**.

The overall description of each step is as follows:

1.  **Choose AMI**: An AMI is a template that contains the software configuration (operating system, application server, and applications) required to launch your instance. You can select an AMI provided by AWS, our user community, or the AWS Marketplace; or you can select one of your own AMIs.

2. **Choose Instance Type**: Amazon EC2 provides a wide selection of instance types optimized to fit different use cases. Instances are virtual servers that can run applications. They have varying combinations of CPU, memory, storage, and networking capacity, and give you the flexibility to choose the appropriate mix of resources for your applications.

3. **Configure Instance**: You can configure the instance to suit your requirements. You can launch multiple instances from the same AMI, request Spot Instances to take advantage of the lower pricing, assign an access management role to the instance, and more.

4. **Add Storage**: Your instance will be launched with the storage device settings shown in this step. You can attach additional EBS volumes and instance store volumes to your instance, or edit the settings of the root volume. You can also attach additional EBS volumes after launching an instance, but not instance store volumes. 

5. **Tag Instance**: A tag consists of a case-sensitive key-value pair. For example, you could define a tag with key = Name and value = Webserver. This values are useful to identify and filter instances in the management screen, to be used in scripts inside your instance, etc.

6. **Configure Security Group**: A security group is a set of firewall rules that control the traffic for your instance. On this step, you can add rules to allow specific traffic to reach your instance. For example, if you want to set up a web server and allow Internet traffic to reach your instance, add rules that allow unrestricted access to the HTTP and HTTPS ports. You can create a new security group or select an existing one. 

7.  **Review**: In this step you can review your instance launch details. You can go back to edit changes for each section. 

### Instances Installation Steps
Login to the AWS Console at [https://console.aws.amazon.com/](https://console.aws.amazon.com/) using your administration credentials and once logged in, select the `EC2` service.

In the top right side of the screen, next to your username and the help link, you should see a dropdown menu. Press it and select `US East (N. Virginia)`. That will change the AWS Region where we will work from now on. We are selecting N. Virginia because is the closest one to the Parse datacenter we are assigned to.

After that, click on `Launch Instance` button inside the Create Instance section. This will launch the Instance Creation Process.

1.  **Choose AMI**: Select the AMI to use for the instance creation. Check that the AMI is the correct one and press the `Select` button to continue. The AMI parameters are:
 	- **Name**: Ubuntu Server 14.04 LTS (HVM), SSD Volume Type 
 	- **Architecture**: 64bits
 	- **AMI**: ami-d05e75b8 
 	- **Root device type**: ebs 
	- **Virtualization type**: hvm

2.  **Choose Instance Type**: on the left hand side menu, select `Compute Optimized`, then select `c4.xlarge` on the table on the right hand side for API machines (or `c4.2xlarge` for DB machines). This will create an instance with the following characteristics:
	- **ECUs**: 14
	- **vCPUs**: 4
	- **Memory**: 7.5
	- **Instance Storage**: EBS Only
	- **Network Performance**: High

3. **Configure Instance**: select the appropriate options as follows:
	- **Number of instances**: enter `1` or `2`.
	- **Purchasing option**: deselect `Request Spot Instances`.
	- **Network**: select `default`.
	- **Subnet**: select `no preference`, unless there are previous servers that would need to access this one. If that's the case, select the same subnet as the previous servers in order to improve communication between the nodes.
	- **Public IP**: check `Automatically assign a Public IP address to your instances`.
	- **IAM Role**: select `none`.
	- **Shutdown behaviour**: select `Stop`.
	- **Enable termination protection**: check `Protect against accidental termination`.
	- **Monitoring**: deselect `Enable CloudWatch detailed monitoring`.
	- **Tenancy**: select `Shared tenancy (multi-tenant hardware)`.
	- **Kernel ID**: select `default`. 
	- **RAM Disk ID**: select `default`.

4. **Add Storage**: check that the size of the `/dev/sda1` device is at least 8GB and that the volume type is `Standard`. In order to not inccur on additional charges once the instance is terminated, keep checked the `Delete on Termination` option.

5. **Tag Instance**: it's a good idea to tag the machine environment and "role". For example, for a production environment, create 2 tags with the following or similar information:
	- **Name**: enter `environment`.
	- **Value**: enter `production`.
	- **Name**: enter `role`.
	- **Value**: enter `pubapi01`.

6. **Configure Security Group**: security group work as sets of firewall rules. It's a usual practice to create a Security Group per application layer and environment, to later reuse the group for all servers in that layer. For the background jobs server in production, enter de following:
	- **Assign a security group**: select `Create a new security group`.
	- **Security group name**: enter `pro_front`.
	- **Description**: enter `Production pub_api layer secgroup`. 
	
	Type | Protocol | Port Range | Source | Comments
	:-----------: | :-----------: | :-----------: | :-----------: | :------------
	SSH | TCP  | 22 | Anywhere | Restrict Source range to office IPs is recommended

**Review**: check that all the information is correct and that Notices don't apply. After that, press the `Launch` button on the bottom right side of the screen. 

## Instance Configuration

### Instance Key Pair 
After pressing `Launch`, you will be presented with the key pair dialog. In this step you can either choose an existing key pair to assign to your new instance, or to create a new key pair. If this is your first instance in your AWS account, you will only be able to create a new key pair. 

Create it and save the key pair information in a secure place. Follow the instructions on the screen to do so. You will also get a file with `.pem` extension. That's the certificate you will need in order to login remotely via SSH to your shiny new instance. Save the file somewhere accesible on your disk and change permissions so that ssh command line utility doesn't complain later on, issuing the following command:

```
sudo chmod 400 <certificatefilename>.pem
```


The instance creation process takes a minute or two, if you have performed the certificate saving steps, probably your instance will be already ready. You can check if your instance is up and running and run other administrative tasks by opening the `Instances` page, clicking on its option on the left hand side of the EC2 Dashboard screen.


### Security Groups Configuration
The basic security group rules have been previously configured during the instance installation process. Nevertheless, security groups can be modified at any time using the AWS Console. 

To modify a Security Group, go to Security Groups option on the left menu in the EC2 administration screen, or click on the Security Group name in the instance information.

In the Security Groups page, select the Security Group you wish to modify, or create a new one. Selecting the Security Group on the top list, enables four tabs below the list:

- **Description**: some descriptive information, such as Group ID.
- **Inbound**: definition of ingress traffic rules.
- **Outbound**: definition of egress traffic rules.
- **Tags**: Name/Value tagging, useful if leveraging AWS API.

Configure the rules for each machine following the Physical Architecture documentation specs.

### Elastic Load Balancer Configuration
Now we should define a Load Balancer for our service. Even if we only use one server to support the service, it's  recommended to use a LB. This will allow us, for example, to expose services using standard HTTP and HTTPS ports. 

Go to the `Load Balancers` option on the left hand side of the EC2 Dashboard and press on the `Create Load Balancer` button. You will be presented with the LB Creation Wizard, in which you'll need to perform 5 easy steps to create your LB:

- **Define Load Balancer**: Begin by giving your new load balancer a unique name so that you can identify it from other load balancers you might create. You will also need to configure ports and protocols for your load balancer. Traffic from your clients can be routed from any load balancer port to any port on your EC2 instances. By default, your load balancer is configured with a standard web server on port 80 rule to your instance. Fill up the following fields with proper info:

	- **Load Balancer Name**: type in an unique name, ie pro-frontend-lb
	- **Create LB Inside**: select the default option
	- **Create an internal load balancer**: deselect the check
	- **Enable advanced VPC configuration**: deselect the check
	- **Listener Configuration**: here we can issue the balancing rules for our LB. Four fields are needed for each rule, being the external protocol and port that will be available publicy and the internal protocol and port the ingress traffic on the external side will be redirected to. For example, to route ingress HTTPS traffic to Play internal HTTP port 9000, use:
	
	 Load Balancer Protocol | Load Balancer Port | Instance Protocol | Instance Port
	:-----------: | :-----------: | :-----------: | :-----------: 
	HTTPS | 443 | HTTP | 9000
	

- **Configure Health Check**:  The LB will automatically perform health checks on your EC2 instances and only route traffic to instances that pass the health check. If an instance fails the health check, it is automatically removed from the load balancer until the health check passes, the instance is considered healthy and it's then restored to the server farm. Customize the health check to meet your specific needs, entering the required info:

	- **Ping Protocol**: usually HTTP will be leveraged.
	- **Ping Port**: typicaly the internal instance port, ie. 9000.
	- **Ping Path**: a URL you want to check, it can be an existing app one or a special one created just for health checking purposes, ie /check.html
	- **Response Timeout**: time to wait when receiving a response from the health check (2 sec - 60 sec). If a correct response is not received in that time, the check is considered failed.
	- **Health Check Interval**: amount of time between health checks (5 sec - 300 sec).
	- **Unhealthy Threshold**: number of consecutive health check failures before declaring an EC2 instance unhealthy, ie 5.
	- **Healthy Threshold**: number of consecutive health check successes before declaring an EC2 instance healthy, ie 3.

- **Assign Security Groups**: here you assign a security group to your LB. You can either create a new secgroup or choose and existing one. For our example, a secgrup allowing ingress HTTPS tcp/443 traffic only would fit. Remember to name it correctly so you won't make mistakes later on.

- **Add EC2 Instances**: now you need to add instances to the LB server farm. The table shown lists all your running EC2 Instances. Check the boxes in the Select column to add the desired instances to the load balancer. Keep the Availability Zone options checked.

**Review**: check that all the information entered is correct and press `Create`. Your LB will be ready in a few minutes. 


### Server Naming and DNS Configuration
It's considered a best practice to name all your servers and not use their IP addresses, public or private, to work with them. This allows for any IP change that might occur, an scenario that's pretty common working with IaaS. In AWS, apart from your Elastic IPs, which are fixed and guaranteed to remain unchanged, any other instance IP might change (usually they don't change during reboots, but that is not guaranteed, and definitelly can change if an instance is shut down).

There are two ways to achieve this: either using local name search (leveraging /etc/hosts file) or preferibly using a DNS service. 

#### Naming convention 
Defining and using a naming convention is a must. [There are a lot of different ways to do this](http://tools.ietf.org/html/rfc2100), but usually all is reduced to creating a meaninful hierarchy that serves your purposes. Typically you would like to know the role of the machine inside your architecture (front, app, mid, api, db...), the environment, (pro, pre, stag, test, dev...) maybe the location or Availability Zone in AWS (bio, mad, nyc...) and an identifier (maybe a numerical one).

With that information, you might define a convention as follows:

```
<role><id>.<env>.<loc>.example.com
```

Examples:

- Production frontend server: `pubapi03.pro.bio.example.com`
- Development database server: `db01.dev.bio.example.com`
- Testing application server: `test02.tst.mad.example.com`
 
 Those names are used **internally**, so that you can locate server to work with them, administer them or for the servers to locate themselves. 
 
 For external, public names, usually a simpler convention is used. For example:
 
 - Web service Load Balancer: `www.example.com` (this routes traffic to front servers)
 - Mail server: `mx.example.com`
 - Admin console for the service: `admin.example.com`
 
 And so on.
 
 Check [this article for an expanded explanation](http://www.mnxsolutions.com/devops/a-proper-server-naming-scheme.html).
 
#### Local Name Search
This is a quick and fast way to work with server names, but implies that naming information must be mantained in a duplicate fashion in every server or machine that needs to access your nodes. Therefore, it's recommended only for a quick test on development or administration machiners, or to provision servers that for security reasons can't have access to a DNS server.

On a typical unix machine, edit the file `/etc/hosts` and add the information as follows:

```
<ip address>	hostname
```

For example:

```
10.0.0.1			www.dev.bio.example.com
10.0.0.2			pubapi01.dev.bio.example.com
10.0.0.3			privapi02.dev.bio.example.com
10.0.2.1			db01.dev.bio.example.com
```

#### DNS based names
The best way to maintain a name resolution service is to leverage the DNS infrastructure. Usually you are given a DNS hosting when you purchase your domain and it's used to provision your server naming scheme. You can also use your own DNS serves (ie [using Bind](https://www.isc.org/downloads/bind/)) or a third party DNS service, such us [AWS Route 53](https://aws.amazon.com/es/route53/).

Some record types that you will probably need:

- **Adress record** `A`: returns a 32bits IPv4 address for the given name.
- **Canonical Name record** `CNAME`: alias of one name to another.
- **Text record** `TXT`: usually employed to populate antispam related data or other machine readable info. 

For a comprehensive list of record types, [check this article](http://en.wikipedia.org/wiki/List_of_DNS_record_types).


### First remote login and OS Updates
To login to your shiny new instance, you first need its public ip address. To find out that, go to the `Instances` section of the EC2 administration page and select your instance on the instance list. Search for the column named `Public IP` and note it down. This is also a good moment to provision that IP either locally or on your DNS infrastructure.

The second thing you need is your `.pem` file containing your private key. Its usually a good idea to keep .pem files in your home directory or in `~/.ssh/`.

To login via ssh to your instance, issue the following command:

```
ssh -i certificatefile.pem ubuntu@<public_ip_adress_or_name_of_the_server>
```
You will be presented with a welcome message and the command prompt for the user `ubuntu`.
This is the default user created by the Ubuntu Server 14.04 LTS AMI and has full `sudo` privileges.


### SSH Configuration

#### Shortcuts
Typing the ssh connection command every time you need to access your server is tiresome. We can define a SSH Shortcut to our server, so we can access it in a faster way.

To do so, we must edit the `~/.ssh/config` file. Open it with your favorite text editor (the example below uses vi). Remember to change the server ip or name and your username fields as well.

In a terminal window, type:

```
vi ~/.ssh/config
```

and then paste following configuration replacing app01 with the id you want to use and location to .pem file with correct one. 

```
Host pubapi01
 
HostName <public_ip_address_or_name_of_the_server> 
User <my_username> 
IdentityFile "~/.ssh/ec2.pem"
```

Save the file and exit the editor. 

To test if everything is working, just try to connect to your server using the shortcut:

```
ssh pubapi01
```

#### Additional Users
By default, the Ubuntu AMI just creates one user called  `ubuntu`. To add additional users and create different ssh keys for each one, perform the steps below.

- Log in to your server and **create a new account**:

	`sudo adduser NewUser`

- Now we will **create the public and private key files** for NewUser (lines starting with `#` are comments and should not be entered):

	```
	su - NewUser
    # Enter the password 
	
    cd ~/
	ssh-keygen -b 1024 -f NewUser -t dsa
	# Enter a passphrase or just press enter to leave it empty
    
	mkdir .ssh
	chmod 700 .ssh
	cat NewUser.pub >> .ssh/authorized_keys
	chmod 600 .ssh/authorized_keys
    chown NewUser .ssh
	chown NewUser .ssh/authorized_keys
	```
    
- If you need your NewUser to be able to administer the machine, **give it sudo priviledges**:

	```
    # Open the sudoers file editor with the following command
    sudo visudo
    
    # Add the following line to the end of the sudoers file
    NewUser   ALL = (ALL)    ALL
	```
    
- We need to **get the private key** we have just created from the server. The private key should be in a file named `~/NewUser`. Just open the file or see its contents with `cat ~/NewUser` and copy/paste the private key to a new local file called `~/.ssh/NewUser.pem` **on your client machine**.

- Before using your key, make sure to **change the permissions to 400**. On your **client** machine, issue the following command to do so:

	```
chmod 400 ~/.ssh/NewUser.pem
	```
    
- Now let’s **test our login** to make sure the private pem files are working. On your client machine:

	```
    ssh -i ~/.ssh/NewUser.pem NewUser@<public_ip_address_or_name_of_the_server>
	```
    
#### Disable Password Authentication
Once you have SSH Keys configured, you can add some extra security to your server by disabling password authentication for SSH. Note that if you do lose your private key, this will make the server inaccessible!!

To disable this setting, you can do the following:

```
sudo vi /etc/ssh/sshd_config
```

In this file, set the following settings to the following values. If these settings are already in the file, set them to "no" rather than add new lines.

```
ChallengeResponseAuthentication no
PasswordAuthentication no
UsePAM no
```
Once this is done, restart the SSH daemon to apply the settings.

```
sudo service ssh restart
```

## Package Management
Ubuntu includes package management tools that will be used to install the required software to build the server. 

The Advanced Packaging Tool, or APT, is a free software user interface that works with core libraries to handle the installation and removal of software on the Debian GNU/Linux distribution and its variants, such as Ubuntu. 

APT simplifies the process of managing software on Unix-like computer systems by automating the retrieval, configuration and installation of software packages, either from precompiled files or by compiling source code.

### APT Tools
There is no single `apt` program, APT is a collection of tools distributed in a package named apt.  apt includes command-line programs for dealing with packages, which use the apt library. Two such programs are `apt-get` and `apt-cache`. 

The apt package is of "important" priority in all current Ubuntu releases, and is therefore installed in a default Ubuntu installation. Apt tools manage relations (especially dependencies) between packages, as well as sourcing and management of higher-level versioning decisions (release tracking and version pinning).

### APT Sources (aka Repositories)
APT relies on the concept of repositories in order to find software and resolve dependencies. For apt, a repository is a directory containing packages along with an index file. This can be specified as a networked or CDROM location. Ubuntu keeps a central repository of over 25,000 software packages ready for download and installation.

Any number of additional repositories can be added to APT's sources.list configuration file `/etc/apt/sources.list` and then be queried by APT. You can do that manually or using other tools such as `add-apt-repository`.

Ubuntu also supports Personal Package Archives (PPAs). PPAs are personal repositories that are often added to `/etc/apt/sources.list` via `add-apt-repository` that people or projects use to deliver software releases to Ubuntu users.

### APT Usage
The typical operations you need to perform using APT are described below.

#### Add a new repository
The software sources are stored in the file called /etc/apt/sources.list. So if you need to add a new repository, issue:

```
sudo add-apt-repository 'deb uri distribution [component1] [component2] [...]'
```

For example:

```
sudo add-apt-repository ppa:chris-lea/node.js
```

Should you wish to remove a repository, use:

```
sudo add-apt-repositor -r ppa:chris-lea/node.js
```


#### Refreshing the package list cache
The first operation is performed using the `apt-get update` command. This command connects to all repositories in `/etc/apt/sources.list` and downloads the latest index available and can be used later on to work with packages. It's therefore the first command you should always execute whenever you are going to work with packages.

```
sudo apt-get update
```

#### Installing new packages
This is the most common command. The `apt-get install` command will install the package and pull in all necessary dependencies, that is other packages that are needed to run the current required package. Usage is again, very simple:

```
sudo apt-get install <package_name>
```

For example, to install nodejs:

```
sudo apt-get install nodejs
```

#### Removing packages
To remove a package, simply use:

```
sudo apt-get remove <package_name>
```

For example, to remove the nodejs package:

```
sudo apt-get remove nodejs
```

#### Upgrading package versions
Upgrading packages is also very straightforward. If you want to upgrade a single package (and all its dependencies), just use `apt-get install` again:

```
sudo apt-get install <package_name>
```

A more common task is upgrading all packages. To do so:

```
sudo apt-get upgrade
```

#### Searching
To search for packages, another tool is used: `apt-cache`. This tools works with the local package indexes and can be used to search for package names, that can later on be installed via `apt-get install`.

For example, to search for all packages related to node, issue:

```
sudo apt-cache search node
```

A list containing package names and descriptions will be shown.


## Base Packages Installation
This section describes the steps needed in order to install all the base software required by the server, using APT.

### Pub API and Priv API Servers
#### Installing Oracle Java 8 JDK
We need to install Oracle Java 8 JDK. Ubuntu includes java JDK in its repositories, but it's not the Oracle one, which exhibits better performance. To install the latest available version in the Ubuntu repositories, we will use a PPA so we can update the JDK later on easily using apt-get. To configure the PPA and install the JDK, simple issue the following commands:

```
sudo add-apt-repository ppa:webupd8team/java
sudo apt-get update
sudo apt-get install oracle-java8-installer
echo "export JAVA_HOME=/usr/lib/jvm/java-8-oracle" >> /home/play/.bashrc
```

This will refresh the local package indexes, get the JDK package and all its dependencies and install them.


Should we need to upgrade the JDK in the future, just issue:

```
sudo apt-get update
sudo apt-get upgrade
```

To check your java installation, type this on a terminal window:

```
$ java -version
```

At the time of this writing (June 2015), the latest version is 8 Update 45.

#### Installing Git
We will use git for our deployments. To install git, simply issue the command below:

```
sudo apt-get update
sudo apt-get install git
```

#### Installing Typesafe Activator
It's usefull to install Activator on development Environment, so we can run our apps in development mode if needed. 
NOTE: If we are building the deployed versions directly on the servers, we will also need to install either Activator or SBT.

To install Activator:

```
sudo apt-get update
sudo apt-get install -y wget zip unzip
cd /tmp
wget http://downloads.typesafe.com/typesafe-activator/1.3.5/typesafe-activator-1.3.5.zip
unzip typesafe-activator-1.3.5.zip
sudo mv mv activator-1.3.5 /opt/activator
sudo chown -R ubuntu:ubuntu /opt/activator
echo "export PATH=$PATH:/opt/activator" >> /home/ubuntu/.bashrc
echo "export _JAVA_OPTIONS='-Duser.home=/home/ubuntu/'" >> /home/ubuntu/.bashrc
```

We can check the activator installation by logging out and logging in again (in order to get the environment variables refreshed) and issuing the following command:

```
activator -h
```


### App Directories
We will keep all our play apps in one place. The directory will be `/opt/app`. We need to create the directory and change the ownership so that node is the owner of that file. In this way, we won't find any permission issues:

```
  cd /opt
  sudo mkdir app
  sudo chown -R ubuntu:ubuntu app
```

### Upstart scripts
[Upstart](http://upstart.ubuntu.com) is an alternative to using standard issue init scripts and is installed by default on Ubuntu. A script resides in the `/etc/init` folder.

Run or check on the script and its process with the following commands:

```
sudo service app start
sudo service app stop
sudo service app status
sudo service app restart
```

### Upstart Configuration
To configure Upstart, we are going to create the upstart init script, copy it to the appropriate location, give it the required permissions and set it up to start automatically if the machine is restarted.

#### Create the Upstart script
Using your favorite text editor, create a file called `app.conf` with the following contents:

```
# An example init script for running a play application as a service.
# 
# You will need to set the environment variables noted below to conform to
# your use case, and change the init info comment block.
#
# Based on:
# http://www.agileand.me/play-2-2-x-upstart-init-script/
#
description "My Play Application"
 
env USER=ubuntu
env GROUP=ubuntu
env APP_HOME=
env APP_NAME=
env PORT=80
env BIND_ADDRESS=0.0.0.0
 
env EXTRA=""
 
start on (filesystem and net-device-up IFACE=lo)
stop on runlevel [!2345]
 
respawn
respawn limit 30 10
umask 022
expect daemon
 
pre-start script
    #If improper shutdown and the PID file is left on disk delete it so we can start again
    if [ -f $APP_HOME/RUNNING_PID ] &amp;&amp; ! ps -p `cat $APP_HOME/RUNNING_PID` > /dev/null ; then
        rm $APP_HOME/RUNNING_PID ;
    fi
end script
 
exec start-stop-daemon --pidfile ${APP_HOME}/RUNNING_PID --chdir ${APP_HOME} --chuid $USER:$GROUP --exec ${APP_HOME}/target/universal/stage/bin/$APP_NAME --background --start -- -Dhttp.port=$PORT -Dhttp.address=$BIND_ADDRESS $EXTRA
```


Then we need to copy the file to init directory:

```
sudo cp app /etc/init/app
```

After putting the script in place, we need to check the script for any syntax errors:

```
init-checkconf /etc/init/app.conf
```

This will check the upstart script syntax. If everything is OK, it displays the following message:

```
$ init-checkconf /etc/init/app.conf
File /etc/init/app.conf: syntax ok
```

Now everything is ready regarding upstart. See Server Management section below for usage.

## Git
We have already installed git using APT in the previous steps. Now we need to set it up for the first time to track our remote release branch on the appropriate directory under `/opt/app`.

### Git user for deployments
We need to setup a the git user `ubuntu` for our deployments. We want it to be able to pull code without prompting for a password, so we need to  provision the public key on github and configure git options.

#### Add the user public key to Github
Using your favorite text editor, open the /home/ubuntu/.ssh/id_rsa.pub file and copy the contents of the file. You can also see the contents from the command line using:

```
su - ubuntu
cat /home/ubuntu/.ssh/id_rsa.pub
```

Example output:
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDqpOS1JaqpRqKYuNLz9kQJfvh9J7mC7ZPJ445asIrViI2HYndM1l/o2S5FOahP8PGKOvMmshtd9vCtWmC0X9NNvE6D8sTHw3Oy/2N4QoGTD88MneYX8LvnzA4bFn03ffiA24zAKNqQTcfswfOd13x9GPwUcHap/li9LudjYtWqGnKi0tMuy5sK8Woj7uzIX0icxq5883GaGRIxlHCOpHztmuPNWZUC+ojaRkhuOEBp+v7UtNDvqWNQMXYBCYCMzj7fJ9gbxijAOSmRD10sdV2ZrqeMEVkdmQ49cQRxie7NWiZc/YuGwBl1PkwJrPWh0diyWkSJMmjxzSJvE/sZA6wP ubuntu@machine
```

Now that you have the key copied, it's time to add it into GitHub.

- In the user bar in the top-right corner of any page, click `Account Settings`.
- Click `SSH Keys` in the left sidebar.
- Click `Add SSH key`.
- In the `Title` field, add a descriptive label for the new key. For example, "Ubuntu <App> deploy key".
- Paste your key into the `Key` field.
- Click `Add key`.
- Confirm the action by entering your GitHub password.

To test that it's working, launch:

```
ssh -vT git@github.com
```

Output:

```
Hi username! You've successfully authenticated...
```

Where username will be your github username (the one you have used to add the public ssh key). With this setup, the deploy script (see below in the Deployments section) will not ask for github authentication.

### Cloning the Release branch
We will be performing our base deploy, cloning the Release branch `production` from our application repository. To do so, log in as ubuntu user and clone the remote branch:

```
cd /opt/app
git clone https://github.com/<BolalaOrganization>/<Bolala-code>.git -b production
```
We now should have all our code from the latest version of the release branch under `/opt/app/Bolala-code`. To check that it's there:

```
cd /opt/app/Bolala-code
ls -la
```

Please **note that you should change the repository url and directory references above ```<BolalaOrganization>/<Bolala-code>``` with the proper ones**.

## Deployment script
We can automate the deployment process with a simple script. This script gets the latest version from the `production` branch we set up before in our app directory `/opt/app/Bolala-code`.

Using a text editor, create the following file and name it `deploy.sh`. We can keep it in the `/opt/app` directory:

```
#!/bin/bash
#
set -e
NAME=app
USER=ubuntu
APPLICATION_DIRECTORY=/opt/app/ball-pubapi

check_upstart_service(){
    status $1 | grep -q "^$1 start" > /dev/null
    return $?
}

start() {

    echo "Deploying $NAME..."

    echo "Changing directory"
    cd $APPLICATION_DIRECTORY
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u})
    echo "Local version is: $LOCAL"
    echo "Remote version is: $REMOTE"

    if [ $LOCAL = $REMOTE ]; then
      echo "Release is up to date!"
    else

      echo "Getting release... $REMOTE"

      if check_upstart_service app; 
      then 
        echo "Stopping Service" 
        sudo service $NAME stop;
      fi

      sudo -u $USER git pull
      echo "Packagin application"
      activator clean stage
      echo "Starting service"
      sudo service $NAME start
      RETVAL=$?
    fi
}

case "$1" in
    start)
        start
        ;;
    *)
        echo "Usage: deploy.sh start"
        exit 1
        ;;
esac
exit $RETVAL
```

Remember to save the file in the `/opt/app` directory.

Now we must change ownership and permissions of the file:

```
sudo chown ubuntu:ubuntu /opt/app/deploy.sh
sudo chmod +x /opt/app/deploy.sh
```

The setup is finished. The `deploy.sh` script performs the following tasks automatically:

- Stops the app
- Pulls the latest version from the release branch
- Starts the app

### Database Servers
#### Installing Oracle Java 8 JDK
We need to install Oracle Java 8 JDK. Ubuntu includes java JDK in its repositories, but it's not the Oracle one, which exhibits better performance. To install the latest available version in the Ubuntu repositories, we will use a PPA so we can update the JDK later on easily using apt-get. To configure the PPA and install the JDK, simple issue the following commands:

```
sudo add-apt-repository ppa:webupd8team/java
sudo apt-get update
sudo apt-get install oracle-java8-installer
echo "export JAVA_HOME=/usr/lib/jvm/java-8-oracle" >> /home/play/.bashrc
```

This will refresh the local package indexes, get the JDK package and all its dependencies and install them.


Should we need to upgrade the JDK in the future, just issue:

```
sudo apt-get update
sudo apt-get upgrade
```

To check your java installation, type this on a terminal window:

```
$ java -version
```

At the time of this writing (June 2015), the latest version is 8 Update 45.

#### Installing Neo4J
We will use the official Neo4J debian repository for the installation.
To add the PPA of the repo, first we need to add the repo key:

```
wget -O - http://debian.neo4j.org/neotechnology.gpg.key | apt-key add -
```

Add Neo4J to the Apt sources list:

```
echo 'deb http://debian.neo4j.org/repo stable/' > /etc/apt/sources.list.d/neo4j.list
```

Update the package manager:

```
sudo apt-get update
```

Install Neo4J:

```
sudo apt-get install neo4j
```

You could replace stable with testing if you want a newer (but unsupported) build of Neo4j. If you'd like a different edition, you can run:

```
apt-get install neo4j-advanced
```

Or

```
apt-get install neo4j-enterprise
```


Neo4J should be running. You can check this with the following command:

```
sudo service neo4j status
```

NOTE: check [Neo4J in Production](http://neo4j.com/developer/in-production/) for guidelines regarding sizing, clustering, etc.



## Server Administration Tasks
### Server Management
We have configured in previous steps Upstart and Forever, so our server management tasks are easy to perform. 

#### Starting our App
Just launch:

```
sudo service app start
```

#### Checking App Status
Just launch:

```
sudo service app status
```

#### Restarting our App
Just launch:

```
sudo service app restart
```

#### Stopping our App
Just launch:

```
sudo service app stop
```

**NOTE**: The commands above are also valid for Neo4J. Just replace ```app``` with ```neo4j```.


### Deployments
To perform a new deployment, simply follow the workflow:

- Code in your development and feature releases using best practises ([Check this for reference](http://nvie.com/posts/a-successful-git-branching-model/))
- Whenever you need to perform a new release, merge your code to the release branch
- SSH into your server and issue the following commands:

	```
	cd /opt/app
    ./deploy.sh start
	```

Check the output for possible errors on restart. A successful run looks like this:

```
$ ./deploy.sh start
Deploying app...
Changing directory
Local version is: b542afccbaaa11330498712395876ffbbaaaafeee
Remote version is: f3d8a32d1932d3bf75fbf4347f36a18cf879170f
Stopping service 
app stop/waiting
Getting release
remote: Counting objects: 21, done.
remote: Compressing objects: 100% (17/17), done.
remote: Total 21 (delta 2), reused 21 (delta 2), pack-reused 0
Unpacking objects: 100% (21/21), done.
From github.com:PerpetuallSoftware/ball-pubapi
   312f029..f3d8a32  production -> origin/production
 * [new branch]      develop    -> origin/develop
   312f029..f3d8a32  master     -> origin/master
Updating 312f029..f3d8a32
Fast-forward
 app/actors/EmailSenderActor.java                | 28 ++++++++++++++++++++++++++++
 app/actors/messages/EmailRecipientsMessage.java |  7 +++++++
 app/aws/AmazonS3Manager.java                    | 66 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 app/controllers/Balls.java                      | 77 +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 app/controllers/security/SecuredAction.java     | 41 +++++++++++++++++++++++++++++++++++++++++
 app/controllers/security/SecuredController.java | 11 +++++++++++
 app/util/RequestDataReader.java                 | 33 +++++++++++++++++++++++++++++++++
 build.sbt                                       | 11 +++++++++++
 conf/application.conf                           | 23 +++++++++++++++++++++++
 conf/play.plugins                               |  1 +
 conf/routes                                     |  8 ++++++--
 11 files changed, 304 insertions(+), 2 deletions(-)
 create mode 100644 app/actors/EmailSenderActor.java
 create mode 100644 app/actors/messages/EmailRecipientsMessage.java
 create mode 100644 app/aws/AmazonS3Manager.java
 create mode 100644 app/controllers/Balls.java
 create mode 100644 app/controllers/security/SecuredAction.java
 create mode 100644 app/controllers/security/SecuredController.java
 create mode 100644 app/util/RequestDataReader.java
 create mode 100644 conf/play.plugins
Packagin application
Picked up _JAVA_OPTIONS: -Duser.home=/home/ubuntu/
Getting org.scala-sbt sbt 0.13.8 ...
downloading file:/opt/activator/repository/org.scala-sbt/sbt/0.13.8/jars/sbt.jar ...
	[SUCCESSFUL ] org.scala-sbt#sbt;0.13.8!sbt.jar (4ms)
downloading file:/opt/activator/repository/org.scala-lang/scala-library/2.10.4/jars/scala-library.jar ...
	[SUCCESSFUL ] org.scala-lang#scala-library;2.10.4!scala-library.jar (191ms)
downloading file:/opt/activator/repository/org.scala-sbt/main/0.13.8/jars/main.jar ...
	[SUCCESSFUL ] org.scala-sbt#main;0.13.8!main.jar (16ms)
downloading file:/opt/activator/repository/org.scala-sbt/compiler-interface/0.13.8/jars/compiler-interface-src.jar ...
	[SUCCESSFUL ] org.scala-sbt#compiler-interface;0.13.8!compiler-interface-src.jar (2ms)
downloading file:/opt/activator/repository/org.scala-sbt/compiler-interface/0.13.8/jars/compiler-interface-bin.jar ...
	[SUCCESSFUL ] org.scala-sbt#compiler-interface;0.13.8!compiler-interface-bin.jar (3ms)
downloading file:/opt/activator/repository/org.scala-sbt/precompiled-2_8_2/0.13.8/jars/compiler-interface-bin.jar ...
	[SUCCESSFUL ] org.scala-sbt#precompiled-2_8_2;0.13.8!compiler-interface-bin.jar (3ms)
downloading file:/opt/activator/repository/org.scala-sbt/precompiled-2_9_2/0.13.8/jars/compiler-interface-bin.jar ...
	[SUCCESSFUL ] org.scala-sbt#precompiled-2_9_2;0.13.8!compiler-interface-bin.jar (3ms)
downloading file:/opt/activator/repository/org.scala-sbt/precompiled-2_9_3/0.13.8/jars/compiler-interface-bin.jar ...
	[SUCCESSFUL ] org.scala-sbt#precompiled-2_9_3;0.13.8!compiler-interface-bin.jar (4ms)
downloading file:/opt/activator/repository/org.scala-sbt/actions/0.13.8/jars/actions.jar ...
	[SUCCESSFUL ] org.scala-sbt#actions;0.13.8!actions.jar (5ms)
downloading file:/opt/activator/repository/org.scala-sbt/main-settings/0.13.8/jars/main-settings.jar ...
	[SUCCESSFUL ] org.scala-sbt#main-settings;0.13.8!main-settings.jar (6ms)
downloading file:/opt/activator/repository/org.scala-sbt/interface/0.13.8/jars/interface.jar ...
	[SUCCESSFUL ] org.scala-sbt#interface;0.13.8!interface.jar (3ms)
downloading file:/opt/activator/repository/org.scala-sbt/io/0.13.8/jars/io.jar ...
	[SUCCESSFUL ] org.scala-sbt#io;0.13.8!io.jar (3ms)
downloading file:/opt/activator/repository/org.scala-sbt/ivy/0.13.8/jars/ivy.jar ...
	[SUCCESSFUL ] org.scala-sbt#ivy;0.13.8!ivy.jar (16ms)
downloading file:/opt/activator/repository/org.scala-sbt/logging/0.13.8/jars/logging.jar ...
	[SUCCESSFUL ] org.scala-sbt#logging;0.13.8!logging.jar (3ms)
downloading file:/opt/activator/repository/org.scala-sbt/logic/0.13.8/jars/logic.jar ...
	[SUCCESSFUL ] org.scala-sbt#logic;0.13.8!logic.jar (2ms)
downloading file:/opt/activator/repository/org.scala-sbt/process/0.13.8/jars/process.jar ...
	[SUCCESSFUL ] org.scala-sbt#process;0.13.8!process.jar (3ms)
downloading file:/opt/activator/repository/org.scala-sbt/run/0.13.8/jars/run.jar ...
	[SUCCESSFUL ] org.scala-sbt#run;0.13.8!run.jar (3ms)
downloading file:/opt/activator/repository/org.scala-sbt/command/0.13.8/jars/command.jar ...
	[SUCCESSFUL ] org.scala-sbt#command;0.13.8!command.jar (4ms)
downloading file:/opt/activator/repository/org.scala-sbt/classpath/0.13.8/jars/classpath.jar ...
	[SUCCESSFUL ] org.scala-sbt#classpath;0.13.8!classpath.jar (2ms)
downloading file:/opt/activator/repository/org.scala-sbt/completion/0.13.8/jars/completion.jar ...
	[SUCCESSFUL ] org.scala-sbt#completion;0.13.8!completion.jar (5ms)
downloading file:/opt/activator/repository/org.scala-sbt/api/0.13.8/jars/api.jar ...
	[SUCCESSFUL ] org.scala-sbt#api;0.13.8!api.jar (4ms)
downloading file:/opt/activator/repository/org.scala-sbt/compiler-integration/0.13.8/jars/compiler-integration.jar ...
	[SUCCESSFUL ] org.scala-sbt#compiler-integration;0.13.8!compiler-integration.jar (3ms)
downloading file:/opt/activator/repository/org.scala-sbt/compiler-ivy-integration/0.13.8/jars/compiler-ivy-integration.jar ...
	[SUCCESSFUL ] org.scala-sbt#compiler-ivy-integration;0.13.8!compiler-ivy-integration.jar (2ms)
downloading file:/opt/activator/repository/org.scala-sbt/relation/0.13.8/jars/relation.jar ...
	[SUCCESSFUL ] org.scala-sbt#relation;0.13.8!relation.jar (1ms)
downloading file:/opt/activator/repository/org.scala-sbt/task-system/0.13.8/jars/task-system.jar ...
	[SUCCESSFUL ] org.scala-sbt#task-system;0.13.8!task-system.jar (2ms)
downloading file:/opt/activator/repository/org.scala-sbt/tasks/0.13.8/jars/tasks.jar ...
	[SUCCESSFUL ] org.scala-sbt#tasks;0.13.8!tasks.jar (3ms)
downloading file:/opt/activator/repository/org.scala-sbt/tracking/0.13.8/jars/tracking.jar ...
	[SUCCESSFUL ] org.scala-sbt#tracking;0.13.8!tracking.jar (2ms)
downloading file:/opt/activator/repository/org.scala-sbt/testing/0.13.8/jars/testing.jar ...
	[SUCCESSFUL ] org.scala-sbt#testing;0.13.8!testing.jar (2ms)
downloading file:/opt/activator/repository/org.scala-lang/scala-compiler/2.10.4/jars/scala-compiler.jar ...
	[SUCCESSFUL ] org.scala-lang#scala-compiler;2.10.4!scala-compiler.jar (89ms)
downloading file:/opt/activator/repository/org.scala-lang/scala-reflect/2.10.4/jars/scala-reflect.jar ...
	[SUCCESSFUL ] org.scala-lang#scala-reflect;2.10.4!scala-reflect.jar (40ms)
downloading file:/opt/activator/repository/org.scala-sbt/control/0.13.8/jars/control.jar ...
	[SUCCESSFUL ] org.scala-sbt#control;0.13.8!control.jar (2ms)
downloading file:/opt/activator/repository/org.scala-sbt/collections/0.13.8/jars/collections.jar ...
	[SUCCESSFUL ] org.scala-sbt#collections;0.13.8!collections.jar (5ms)
downloading file:/opt/activator/repository/org.scala-sbt/incremental-compiler/0.13.8/jars/incremental-compiler.jar ...
	[SUCCESSFUL ] org.scala-sbt#incremental-compiler;0.13.8!incremental-compiler.jar (6ms)
downloading file:/opt/activator/repository/org.scala-sbt/compile/0.13.8/jars/compile.jar ...
	[SUCCESSFUL ] org.scala-sbt#compile;0.13.8!compile.jar (3ms)
downloading file:/opt/activator/repository/org.scala-sbt/persist/0.13.8/jars/persist.jar ...
	[SUCCESSFUL ] org.scala-sbt#persist;0.13.8!persist.jar (3ms)
downloading file:/opt/activator/repository/org.scala-sbt/classfile/0.13.8/jars/classfile.jar ...
	[SUCCESSFUL ] org.scala-sbt#classfile;0.13.8!classfile.jar (3ms)
downloading file:/opt/activator/repository/org.scala-tools.sbinary/sbinary_2.10/0.4.2/jars/sbinary_2.10.jar ...
	[SUCCESSFUL ] org.scala-tools.sbinary#sbinary_2.10;0.4.2!sbinary_2.10.jar (2ms)
downloading file:/opt/activator/repository/org.scala-sbt/cross/0.13.8/jars/cross.jar ...
	[SUCCESSFUL ] org.scala-sbt#cross;0.13.8!cross.jar (2ms)
downloading file:/opt/activator/repository/org.scala-sbt.ivy/ivy/2.3.0-sbt-fccfbd44c9f64523b61398a0155784dcbaeae28f/jars/ivy.jar ...
	[SUCCESSFUL ] org.scala-sbt.ivy#ivy;2.3.0-sbt-fccfbd44c9f64523b61398a0155784dcbaeae28f!ivy.jar (10ms)
downloading file:/opt/activator/repository/com.jcraft/jsch/0.1.46/jars/jsch.jar ...
	[SUCCESSFUL ] com.jcraft#jsch;0.1.46!jsch.jar (5ms)
downloading file:/opt/activator/repository/org.scala-sbt/serialization_2.10/0.1.1/jars/serialization_2.10.jar ...
	[SUCCESSFUL ] org.scala-sbt#serialization_2.10;0.1.1!serialization_2.10.jar (5ms)
downloading file:/opt/activator/repository/org.scala-lang.modules/scala-pickling_2.10/0.10.0/jars/scala-pickling_2.10.jar ...
	[SUCCESSFUL ] org.scala-lang.modules#scala-pickling_2.10;0.10.0!scala-pickling_2.10.jar (9ms)
downloading file:/opt/activator/repository/org.json4s/json4s-core_2.10/3.2.10/jars/json4s-core_2.10.jar ...
	[SUCCESSFUL ] org.json4s#json4s-core_2.10;3.2.10!json4s-core_2.10.jar (7ms)
downloading file:/opt/activator/repository/org.spire-math/jawn-parser_2.10/0.6.0/jars/jawn-parser_2.10.jar ...
	[SUCCESSFUL ] org.spire-math#jawn-parser_2.10;0.6.0!jawn-parser_2.10.jar (2ms)
downloading file:/opt/activator/repository/org.spire-math/json4s-support_2.10/0.6.0/jars/json4s-support_2.10.jar ...
	[SUCCESSFUL ] org.spire-math#json4s-support_2.10;0.6.0!json4s-support_2.10.jar (2ms)
downloading file:/opt/activator/repository/org.scalamacros/quasiquotes_2.10/2.0.1/jars/quasiquotes_2.10.jar ...
	[SUCCESSFUL ] org.scalamacros#quasiquotes_2.10;2.0.1!quasiquotes_2.10.jar (9ms)
downloading file:/opt/activator/repository/org.json4s/json4s-ast_2.10/3.2.10/jars/json4s-ast_2.10.jar ...
	[SUCCESSFUL ] org.json4s#json4s-ast_2.10;3.2.10!json4s-ast_2.10.jar (2ms)
downloading file:/opt/activator/repository/com.thoughtworks.paranamer/paranamer/2.6/jars/paranamer.jar ...
	[SUCCESSFUL ] com.thoughtworks.paranamer#paranamer;2.6!paranamer.jar (2ms)
downloading file:/opt/activator/repository/org.scala-sbt/cache/0.13.8/jars/cache.jar ...
	[SUCCESSFUL ] org.scala-sbt#cache;0.13.8!cache.jar (2ms)
downloading file:/opt/activator/repository/org.scala-sbt/test-agent/0.13.8/jars/test-agent.jar ...
	[SUCCESSFUL ] org.scala-sbt#test-agent;0.13.8!test-agent.jar (1ms)
downloading file:/opt/activator/repository/org.scala-sbt/test-interface/1.0/jars/test-interface.jar ...
	[SUCCESSFUL ] org.scala-sbt#test-interface;1.0!test-interface.jar (1ms)
downloading file:/opt/activator/repository/org.scala-sbt/apply-macro/0.13.8/jars/apply-macro.jar ...
	[SUCCESSFUL ] org.scala-sbt#apply-macro;0.13.8!apply-macro.jar (4ms)
:: retrieving :: org.scala-sbt#boot-app
	confs: [default]
	52 artifacts copied, 0 already retrieved (17674kB/92ms)
Getting Scala 2.10.4 (for sbt)...
downloading file:/opt/activator/repository/org.scala-lang/jline/2.10.4/jars/jline.jar ...
	[SUCCESSFUL ] org.scala-lang#jline;2.10.4!jline.jar (4ms)
downloading file:/opt/activator/repository/org.fusesource.jansi/jansi/1.4/jars/jansi.jar ...
	[SUCCESSFUL ] org.fusesource.jansi#jansi;1.4!jansi.jar (3ms)
:: retrieving :: org.scala-sbt#boot-scala
	confs: [default]
	5 artifacts copied, 0 already retrieved (24459kB/39ms)
[info] Loading project definition from /opt/app/ball-pubapi/project
[info] Set current project to ball-pubapi (in build file:/opt/app/ball-pubapi/)
[success] Total time: 0 s, completed Jun 26, 2015 9:29:41 AM
[info] Packaging /opt/app/ball-pubapi/target/scala-2.11/ball-pubapi_2.11-1.0-sources.jar ...
[info] Done packaging.
[info] Updating {file:/opt/app/ball-pubapi/}root...
[info] Wrote /opt/app/ball-pubapi/target/scala-2.11/ball-pubapi_2.11-1.0.pom
[info] Resolving jline#jline;2.12.1 ...
[info] downloading https://repo1.maven.org/maven2/org/scala-lang/scala-library/2.11.7/scala-library-2.11.7.jar ...
[info] 	[SUCCESSFUL ] org.scala-lang#scala-library;2.11.7!scala-library.jar (1551ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk/1.10.1/aws-java-sdk-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk;1.10.1!aws-java-sdk.jar (102ms)
[info] downloading https://repo1.maven.org/maven2/com/sendgrid/sendgrid-java/2.2.2/sendgrid-java-2.2.2.jar ...
[info] 	[SUCCESSFUL ] com.sendgrid#sendgrid-java;2.2.2!sendgrid-java.jar (115ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-support/1.10.1/aws-java-sdk-support-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-support;1.10.1!aws-java-sdk-support.jar (216ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-simpledb/1.10.1/aws-java-sdk-simpledb-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-simpledb;1.10.1!aws-java-sdk-simpledb.jar (165ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-simpleworkflow/1.10.1/aws-java-sdk-simpleworkflow-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-simpleworkflow;1.10.1!aws-java-sdk-simpleworkflow.jar (432ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-storagegateway/1.10.1/aws-java-sdk-storagegateway-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-storagegateway;1.10.1!aws-java-sdk-storagegateway.jar (670ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-route53/1.10.1/aws-java-sdk-route53-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-route53;1.10.1!aws-java-sdk-route53.jar (489ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-s3/1.10.1/aws-java-sdk-s3-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-s3;1.10.1!aws-java-sdk-s3.jar (331ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-importexport/1.10.1/aws-java-sdk-importexport-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-importexport;1.10.1!aws-java-sdk-importexport.jar (283ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-sts/1.10.1/aws-java-sdk-sts-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-sts;1.10.1!aws-java-sdk-sts.jar (124ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-sqs/1.10.1/aws-java-sdk-sqs-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-sqs;1.10.1!aws-java-sdk-sqs.jar (170ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-rds/1.10.1/aws-java-sdk-rds-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-rds;1.10.1!aws-java-sdk-rds.jar (284ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-redshift/1.10.1/aws-java-sdk-redshift-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-redshift;1.10.1!aws-java-sdk-redshift.jar (304ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-elasticbeanstalk/1.10.1/aws-java-sdk-elasticbeanstalk-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-elasticbeanstalk;1.10.1!aws-java-sdk-elasticbeanstalk.jar (226ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-glacier/1.10.1/aws-java-sdk-glacier-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-glacier;1.10.1!aws-java-sdk-glacier.jar (184ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-iam/1.10.1/aws-java-sdk-iam-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-iam;1.10.1!aws-java-sdk-iam.jar (321ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-datapipeline/1.10.1/aws-java-sdk-datapipeline-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-datapipeline;1.10.1!aws-java-sdk-datapipeline.jar (182ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-elasticloadbalancing/1.10.1/aws-java-sdk-elasticloadbalancing-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-elasticloadbalancing;1.10.1!aws-java-sdk-elasticloadbalancing.jar (235ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-emr/1.10.1/aws-java-sdk-emr-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-emr;1.10.1!aws-java-sdk-emr.jar (193ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-elasticache/1.10.1/aws-java-sdk-elasticache-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-elasticache;1.10.1!aws-java-sdk-elasticache.jar (230ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-elastictranscoder/1.10.1/aws-java-sdk-elastictranscoder-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-elastictranscoder;1.10.1!aws-java-sdk-elastictranscoder.jar (184ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-ec2/1.10.1/aws-java-sdk-ec2-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-ec2;1.10.1!aws-java-sdk-ec2.jar (662ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-dynamodb/1.10.1/aws-java-sdk-dynamodb-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-dynamodb;1.10.1!aws-java-sdk-dynamodb.jar (302ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-sns/1.10.1/aws-java-sdk-sns-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-sns;1.10.1!aws-java-sdk-sns.jar (158ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-cloudtrail/1.10.1/aws-java-sdk-cloudtrail-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-cloudtrail;1.10.1!aws-java-sdk-cloudtrail.jar (136ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-cloudwatch/1.10.1/aws-java-sdk-cloudwatch-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-cloudwatch;1.10.1!aws-java-sdk-cloudwatch.jar (165ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-logs/1.10.1/aws-java-sdk-logs-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-logs;1.10.1!aws-java-sdk-logs.jar (253ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-cognitoidentity/1.10.1/aws-java-sdk-cognitoidentity-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-cognitoidentity;1.10.1!aws-java-sdk-cognitoidentity.jar (167ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-cognitosync/1.10.1/aws-java-sdk-cognitosync-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-cognitosync;1.10.1!aws-java-sdk-cognitosync.jar (183ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-directconnect/1.10.1/aws-java-sdk-directconnect-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-directconnect;1.10.1!aws-java-sdk-directconnect.jar (161ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-cloudformation/1.10.1/aws-java-sdk-cloudformation-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-cloudformation;1.10.1!aws-java-sdk-cloudformation.jar (198ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-cloudfront/1.10.1/aws-java-sdk-cloudfront-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-cloudfront;1.10.1!aws-java-sdk-cloudfront.jar (354ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-kinesis/1.10.1/aws-java-sdk-kinesis-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-kinesis;1.10.1!aws-java-sdk-kinesis.jar (193ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-opsworks/1.10.1/aws-java-sdk-opsworks-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-opsworks;1.10.1!aws-java-sdk-opsworks.jar (292ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-ses/1.10.1/aws-java-sdk-ses-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-ses;1.10.1!aws-java-sdk-ses.jar (151ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-autoscaling/1.10.1/aws-java-sdk-autoscaling-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-autoscaling;1.10.1!aws-java-sdk-autoscaling.jar (243ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-cloudsearch/1.10.1/aws-java-sdk-cloudsearch-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-cloudsearch;1.10.1!aws-java-sdk-cloudsearch.jar (270ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-cloudwatchmetrics/1.10.1/aws-java-sdk-cloudwatchmetrics-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-cloudwatchmetrics;1.10.1!aws-java-sdk-cloudwatchmetrics.jar (128ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-swf-libraries/1.10.1/aws-java-sdk-swf-libraries-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-swf-libraries;1.10.1!aws-java-sdk-swf-libraries.jar (238ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-codedeploy/1.10.1/aws-java-sdk-codedeploy-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-codedeploy;1.10.1!aws-java-sdk-codedeploy.jar (321ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-kms/1.10.1/aws-java-sdk-kms-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-kms;1.10.1!aws-java-sdk-kms.jar (174ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-config/1.10.1/aws-java-sdk-config-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-config;1.10.1!aws-java-sdk-config.jar (158ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-lambda/1.10.1/aws-java-sdk-lambda-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-lambda;1.10.1!aws-java-sdk-lambda.jar (160ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-ecs/1.10.1/aws-java-sdk-ecs-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-ecs;1.10.1!aws-java-sdk-ecs.jar (202ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-cloudhsm/1.10.1/aws-java-sdk-cloudhsm-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-cloudhsm;1.10.1!aws-java-sdk-cloudhsm.jar (158ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-ssm/1.10.1/aws-java-sdk-ssm-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-ssm;1.10.1!aws-java-sdk-ssm.jar (144ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-workspaces/1.10.1/aws-java-sdk-workspaces-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-workspaces;1.10.1!aws-java-sdk-workspaces.jar (133ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-machinelearning/1.10.1/aws-java-sdk-machinelearning-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-machinelearning;1.10.1!aws-java-sdk-machinelearning.jar (207ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-directory/1.10.1/aws-java-sdk-directory-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-directory;1.10.1!aws-java-sdk-directory.jar (162ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-efs/1.10.1/aws-java-sdk-efs-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-efs;1.10.1!aws-java-sdk-efs.jar (151ms)
[info] downloading https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-core/1.10.1/aws-java-sdk-core-1.10.1.jar ...
[info] 	[SUCCESSFUL ] com.amazonaws#aws-java-sdk-core;1.10.1!aws-java-sdk-core.jar (355ms)
[info] downloading https://repo1.maven.org/maven2/org/apache/httpcomponents/httpclient/4.3.6/httpclient-4.3.6.jar ...
[info] 	[SUCCESSFUL ] org.apache.httpcomponents#httpclient;4.3.6!httpclient.jar (242ms)
[info] downloading https://repo1.maven.org/maven2/joda-time/joda-time/2.8.1/joda-time-2.8.1.jar ...
[info] 	[SUCCESSFUL ] joda-time#joda-time;2.8.1!joda-time.jar (249ms)
[info] downloading https://repo1.maven.org/maven2/org/apache/httpcomponents/httpcore/4.3.3/httpcore-4.3.3.jar ...
[info] 	[SUCCESSFUL ] org.apache.httpcomponents#httpcore;4.3.3!httpcore.jar (166ms)
[info] downloading https://repo1.maven.org/maven2/org/apache/httpcomponents/httpmime/4.3.4/httpmime-4.3.4.jar ...
[info] 	[SUCCESSFUL ] org.apache.httpcomponents#httpmime;4.3.4!httpmime.jar (149ms)
[info] downloading https://repo1.maven.org/maven2/org/json/json/20140107/json-20140107.jar ...
[info] 	[SUCCESSFUL ] org.json#json;20140107!json.jar (134ms)
[info] downloading https://repo1.maven.org/maven2/com/sendgrid/smtpapi-java/1.2.0/smtpapi-java-1.2.0.jar ...
[info] 	[SUCCESSFUL ] com.sendgrid#smtpapi-java;1.2.0!smtpapi-java.jar (99ms)
[info] downloading https://repo1.maven.org/maven2/org/scala-lang/scala-compiler/2.11.7/scala-compiler-2.11.7.jar ...
[info] 	[SUCCESSFUL ] org.scala-lang#scala-compiler;2.11.7!scala-compiler.jar (4108ms)
[info] downloading https://repo1.maven.org/maven2/org/scala-lang/scala-reflect/2.11.7/scala-reflect-2.11.7.jar ...
[info] 	[SUCCESSFUL ] org.scala-lang#scala-reflect;2.11.7!scala-reflect.jar (1217ms)
[info] downloading https://repo1.maven.org/maven2/org/scala-lang/modules/scala-xml_2.11/1.0.4/scala-xml_2.11-1.0.4.jar ...
[info] 	[SUCCESSFUL ] org.scala-lang.modules#scala-xml_2.11;1.0.4!scala-xml_2.11.jar(bundle) (1064ms)
[info] downloading https://repo1.maven.org/maven2/org/scala-lang/modules/scala-parser-combinators_2.11/1.0.4/scala-parser-combinators_2.11-1.0.4.jar ...
[info] 	[SUCCESSFUL ] org.scala-lang.modules#scala-parser-combinators_2.11;1.0.4!scala-parser-combinators_2.11.jar(bundle) (548ms)
[info] Done updating.
[info] Main Scala API documentation to /opt/app/ball-pubapi/target/scala-2.11/api...
[info] 'compiler-interface' not yet compiled for Scala 2.11.7. Compiling...
[info] Compiling 6 Scala sources and 9 Java sources to /opt/app/ball-pubapi/target/scala-2.11/classes...
[info]   Compilation completed in 12.556 s
model contains 34 documentable templates
[info] Main Scala API documentation successful.
[info] Packaging /opt/app/ball-pubapi/target/scala-2.11/ball-pubapi_2.11-1.0-javadoc.jar ...
[info] Done packaging.
[info] Packaging /opt/app/ball-pubapi/target/scala-2.11/ball-pubapi_2.11-1.0-web-assets.jar ...
[info] Done packaging.
[info] Packaging /opt/app/ball-pubapi/target/scala-2.11/ball-pubapi_2.11-1.0.jar ...
[info] Done packaging.
[success] Total time: 63 s, completed Jun 26, 2015 9:30:45 AM
Starting service
app start/running, process 8771
```

The deploy script shows current local version and remote version. Look for that info in the beginning of the execution log:

```
Local version is: b542afccbaaa11330498712395876ffbbaaaafeee
Remote version is: f3d8a32d1932d3bf75fbf4347f36a18cf879170f
```

If the remote version is the same as the one already deployed, no updating is needed:

```
./deploy.sh start
Deploying app...
Changing directory
Local version is: f3d8a32d1932d3bf75fbf4347f36a18cf879170f
Remote version is: f3d8a32d1932d3bf75fbf4347f36a18cf879170f
Release is up to date!
```

**It's best practice to run this procedure in the preproduction first so that any possible deployment error is fixed before production.**

If no error appears, remember to check that the app is running ok:

```
sudo service app status
$ ps auxwww|grep java
ubuntu    9378  0.0  0.5 2765456 19516 ?       Sl   09:30   0:00 java -Duser.dir=/opt/app/ball-pubapi/target/universal/stage -Dhttp.port=80 -Dhttp.address=0.0.0.0 -cp /opt/app/ball-pubapi/target/universal/stage/lib/../conf:/opt/app/ball-pubapi/target/universal/stage/lib/ball-pubapi.ball-pubapi-1.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/org.scala-lang.scala-library-2.11.7.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.typesafe.play.twirl-api_2.11-1.1.1.jar:/opt/app/ball-pubapi/target/universal/stage/lib/org.apache.commons.commons-lang3-3.4.jar:/opt/app/ball-pubapi/target/universal/stage/lib/org.scala-lang.modules.scala-xml_2.11-1.0.1.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.typesafe.play.play-server_2.11-2.4.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.typesafe.play.play_2.11-2.4.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.typesafe.play.build-link-2.4.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.typesafe.play.play-exceptions-2.4.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/org.javassist.javassist-3.19.0-GA.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.typesafe.play.play-iteratees_2.11-2.4.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/org.scala-stm.scala-stm_2.11-0.7.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.typesafe.config-1.3.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.typesafe.play.play-json_2.11-2.4.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.typesafe.play.play-functional_2.11-2.4.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.typesafe.play.play-datacommons_2.11-2.4.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/org.joda.joda-convert-1.7.jar:/opt/app/ball-pubapi/target/universal/stage/lib/org.scala-lang.scala-reflect-2.11.6.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.fasterxml.jackson.core.jackson-core-2.5.3.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.fasterxml.jackson.core.jackson-annotations-2.5.3.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.fasterxml.jackson.core.jackson-databind-2.5.3.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.fasterxml.jackson.datatype.jackson-datatype-jdk8-2.5.3.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.fasterxml.jackson.datatype.jackson-datatype-jsr310-2.5.3.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.typesafe.play.play-netty-utils-2.4.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/org.slf4j.slf4j-api-1.7.12.jar:/opt/app/ball-pubapi/target/universal/stage/lib/org.slf4j.jul-to-slf4j-1.7.12.jar:/opt/app/ball-pubapi/target/universal/stage/lib/org.slf4j.jcl-over-slf4j-1.7.12.jar:/opt/app/ball-pubapi/target/universal/stage/lib/org.scala-lang.modules.scala-parser-combinators_2.11-1.0.1.jar:/opt/app/ball-pubapi/target/universal/stage/lib/ch.qos.logback.logback-core-1.1.3.jar:/opt/app/ball-pubapi/target/universal/stage/lib/ch.qos.logback.logback-classic-1.1.3.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.typesafe.akka.akka-actor_2.11-2.3.11.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.typesafe.akka.akka-slf4j_2.11-2.3.11.jar:/opt/app/ball-pubapi/target/universal/stage/lib/commons-codec.commons-codec-1.10.jar:/opt/app/ball-pubapi/target/universal/stage/lib/xerces.xercesImpl-2.11.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/xml-apis.xml-apis-1.4.01.jar:/opt/app/ball-pubapi/target/universal/stage/lib/javax.transaction.jta-1.1.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.google.inject.guice-4.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/javax.inject.javax.inject-1.jar:/opt/app/ball-pubapi/target/universal/stage/lib/aopalliance.aopalliance-1.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.google.inject.extensions.guice-assistedinject-4.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/com.typesafe.play.play-java_2.11-2.4.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/org.scala-lang.modules.scala-java8-compat_2.11-0.3.0.jar:/opt/app/ball-pubapi/target/universal/stage/lib/org.yaml.snakeyaml-1.15.jar:/opt/app/ball-pubapi/target/universal/stage/lib/org.hibernate.hib
```


Also, check the configured log file for any other app error.

