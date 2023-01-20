#!/bin/bash

echo "This script Install Kubernetes MASTER node on CentOS"


# Check for hardware prerequisites
mem_size=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
echo "Minimum memory required : 2097152 KB"
echo "Available memory : $mem_size KB "
if [[ $mem_size -lt 2097152 ]]; then
  echo "Error: Your system does not meet the minimum memory requirement of 2GB " >&2
  exit 1
fi

num_cpus=$(nproc)
echo "Minimum CPU cores required : 2 cores"
echo "Available CPU cores : $num_cpus cores"
if [[ $num_cpus -lt 2 ]]; then
  echo "Error: Your system does not meet the minimum CPU requirement of 2 cores " >&2
  exit 1
fi

# Confirm with the user before proceeding
read -p "Do you want to proceed with the installation ? (y/n) " -n 1 -r
echo   
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

# Check for software prerequisites
if ! [ -x "$(command -v curl)" ]; then
  echo 'Error: curl is not installed.' >&2
  exit 1
fi
if ! [ -x "$(command -v yum)" ]; then
  echo 'Error: yum is not installed.' >&2
  exit 1
fi

# Get the hostname
echo "Enter the hostname:"
read hostname
hostnamectl set-hostname $hostname
echo "`ip route get 1 | awk '{print $NF;exit}'` $hostname" >> /etc/hosts


# Update the package list and upgrade all packages
yum update -y

# Install necessary packages
yum install -y yum-utils device-mapper-persistent-data lvm2

# Add Kubernetes repository
cat << EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

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

# Set sysctl net.bridge.bridge-nf-call-iptables to 1
echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
sysctl --system

# Set SELinux in permissive mode
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Add ports to firewall
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --permanent --add-port=2379-2380/tcp
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=10251/tcp
sudo firewall-cmd --permanent --add-port=10252/tcp
sudo firewall-cmd --permanent --add-port=10255/tcp
sudo firewall-cmd –reload


# Install Kubernetes components
yum install -y kubelet kubeadm kubectl

# Enable and start kubelet service
systemctl enable --now kubelet

# Initialize kubeadm
kubeadm init --ignore-preflight-errors=Firewalld

# Copy kubeconfig to home directory
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


#Deploy a pod network
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.49.0/deploy/static/provider/baremetal/deploy.yaml


#Cluster join link
clear
echo " Installation Successfull "
echo " use below "
kubeadm token create --print-join-command

