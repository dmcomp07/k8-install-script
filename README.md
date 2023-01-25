# kubernetes Installation Scripts
scripts for the installation of Kubernetes Master Node, Worker Node, Kubernetes Kind and Minikube on CentOS/ Ubuntu operating system. 
These scripts simplify the process of setting up a Kubernetes cluster and make it easy for developers to get started with Kubernetes.


# How use these scripts for Installation ?
1. Download or just Copy-paste scripts from repository and use
2. Use another scipt written below: just Copy- paste to CentOS / Ubuntu  & follow Instructions.
   it'll list all available scripts, select the script you want to install and that's it. 
   
   sit tight and wait for Successful Installation.


```bash

#This script collects all scripts on Github repository and provide option to Install on CentOS/ Ubuntu


cat <<EOF > k10.sh

#!/bin/bash

# Define the Github repository
repo="https://github.com/dmcomp07/k8-install-script"


# check the OS
if [ -f /etc/redhat-release ]; then
    # code for CentOS
    echo "Running on CentOS"

# Check if git is installed, if not install it
if ! [ -x "\$(command -v git)" ]; then
  yum install git -y
fi

#install dependencies
yum install -y epel-release	
	
elif [ -f /etc/lsb-release ]; then
    # code for Ubuntu
    echo "Running on Ubuntu"

# Check if git is installed, if not install it
if ! [ -x "\$(command -v git)" ]; then
  apt-get install git -y
fi
	
else
    # code for other OS
    echo "Not a supported OS"
    exit
fi	

# Clone the Github repository
git clone \$repo

# Go to the repository directory
cd k8-install-script


# List all the script files in the repository
echo "Please choose which script you want to install:"
ls -1 | grep -E '*.sh'
read -p "Enter the script name: " script_name
chmod +x \$script_name
./\$script_name

EOF
chmod +x k10.sh
./k10.sh
```
