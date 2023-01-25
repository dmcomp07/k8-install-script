#!/bin/bash

# check the OS
if [ -f /etc/redhat-release ]; then
    # code for CentOS
    echo "Running on CentOS"
cat << EOF > k8.sh
#!/bin/bash

echo "

        #################################################################
        #                                                               #
        #       This Script Install Kubernetes MINIKUBE on CentOS       #
        #                                                               #
        #################################################################


"
# Check for hardware prerequisites
mem_size=\$(cat /proc/meminfo | grep MemTotal | awk '{print \$2}')
echo "Minimum memory required : 2097152 KB"
echo "Available memory : \$mem_size KB "
if [[ \$mem_size -lt 2097152 ]]; then
  echo "Error: Your system does not meet the minimum memory requirement of 2GB " >&2
  exit 1
fi

num_cpus=\$(nproc)
echo "Minimum CPU cores required : 2 cores"
echo "Available CPU cores : \$num_cpus cores"
if [[ \$num_cpus -lt 2 ]]; then
  echo "Error: Your system does not meet the minimum CPU requirement of 2 cores " >&2
  exit 1
fi


# Confirm with the user before proceeding
read -p "Do you want to proceed with the installation ? (y/n) " -n 1 -r
echo   
if [[ ! \$REPLY =~ ^[Yy]\$ ]]
then
    exit 1
fi


# Check for software prerequisites
if ! [ -x "\$(command -v curl)" ]; then
  echo 'Error: curl is not installed.' >&2
  exit 1
fi
if ! [ -x "\$(command -v yum)" ]; then
  echo 'Error: yum is not installed.' >&2
  exit 1
fi


# Get the hostname
echo "Enter the hostname:"
read hostname
hostnamectl set-hostname \$hostname
echo "`ip route get 1 | awk '{print \$NF;exit}'` \$hostname" >> /etc/hosts

# Install dependencies
sudo yum install -y conntrack


# Install necessary packages
yum install -y yum-utils device-mapper-persistent-data lvm2

#Install docker
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum -y update
sudo yum -y install docker-ce docker-ce-cli docker-compose-plugin --skip-broken

systemctl start docker
systemctl enable docker


# Remove containerd config file
yum install -y containerd.io
rm -f /etc/containerd/config.toml

# Restart containerd service
systemctl restart containerd
chkconfig --add containerd

# Add the kubeadm repo
printf "
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg

" > /etc/yum.repos.d/kubernetes.repo

# Install minikube
sudo yum install -y kubectl kubelet kubeadm
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube
sudo mv minikube /usr/local/bin/

echo "export PATH=\$PATH:/usr/local/bin" >> ~/.bashrc
source ~/.bashrc



# Configure kubelet to use containerd as the CRI
sudo sh -c "echo 'KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock' >> /etc/sysconfig/kubelet"

# Restart kubelet service
sudo systemctl restart kubelet


# Start minikube with containerd as the runtime
minikube start --driver=docker --force


EOF

chmod +x k8.sh
./k8.sh


	
	
	
elif [ -f /etc/lsb-release ]; then
    # code for Ubuntu
    echo "Running on Ubuntu"
cat << EOF > k8.sh

#!/bin/bash

echo "

        #################################################################
        #                                                               #
        #       This Script Install Kubernetes MINIKUBE on Ubuntu       #
        #                                                               #
        #################################################################


"
# Check for hardware prerequisites
mem_size=\$(cat /proc/meminfo | grep MemTotal | awk '{print \$2}')
echo "Minimum memory required : 2097152 KB"
echo "Available memory : \$mem_size KB "
if [[ \$mem_size -lt 2097152 ]]; then
  echo "Error: Your system does not meet the minimum memory requirement of 2GB " >&2
  exit 1
fi

num_cpus=\$(nproc)
echo "Minimum CPU cores required : 2 cores"
echo "Available CPU cores : \$num_cpus cores"
if [[ \$num_cpus -lt 2 ]]; then
  echo "Error: Your system does not meet the minimum CPU requirement of 2 cores " >&2
  exit 1
fi

# Confirm with the user before proceeding
read -p "Do you want to proceed with the installation ? (y/n) " -n 1 -r
echo   
if [[ ! \$REPLY =~ ^[Yy]\$ ]]
then
    exit 1
fi


# Check for software prerequisites
if ! [ -x "\$(command -v curl)" ]; then
  echo 'Error: curl is not installed.' >&2
  exit 1
fi
if ! [ -x "\$(command -v apt-get)" ]; then
  echo 'Error: apt-get is not installed.' >&2
  exit 1
fi

# Get the hostname
echo "Enter the hostname:"
read hostname
hostnamectl set-hostname \$hostname
echo "`ip route get 1 | awk '{print \$NF;exit}'` \$hostname" >> /etc/hosts

# Install dependencies
sudo apt-get install -y conntrack

# Update the apt package list and install necessary packages
sudo apt-get update -y
sudo apt-get install -y yum-utils device-mapper-persistent-data lvm2

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

systemctl start docker
systemctl enable docker

# Remove containerd config file
rm -f /etc/containerd/config.toml

# Restart containerd service
systemctl restart containerd
systemctl enable containerd

# Add the kubeadm repo
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y

# Install kubectl, kubelet, and kubeadm
sudo apt-get install -y kubectl kubelet kubeadm

# Download minikube binary
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

# Make the binary executable
chmod +x minikube

# Move the binary to a directory in PATH
sudo mv minikube /usr/local/bin/

# Add the directory to PATH in .bashrc
echo "export PATH=\$PATH:/usr/local/bin" >> ~/.bashrc

# Reload .bashrc
source ~/.bashrc

# Configure kubelet to use containerd as the CRI
sudo sh -c "echo 'KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock' >> /etc/sysconfig/kubelet"

# Restart kubelet service
sudo systemctl restart kubelet

# Start minikube with containerd as the runtime
minikube start --driver=docker --force


EOF

chmod +x k8.sh
./k8.sh	
	
	
else
    # code for other OS
    echo "Not a supported OS"
    exit
fi
