#!/bin/bash

# Update system
sudo yum update -y

# Install dependencies
sudo yum install -y conntrack socat


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

# Download and install Kind
curl -Lo kind https://kind.sigs.k8s.io/dl/v0.11.0/kind-linux-amd64
chmod +x kind
sudo mv kind /usr/local/bin/
echo "export PATH=$PATH:/usr/local/bin" >> ~/.bashrc
source ~/.bashrc


# Verify Kind installation
kind version

# Create a cluster
kind create cluster

# Verify installation
kubectl cluster-info --context kind-kind
