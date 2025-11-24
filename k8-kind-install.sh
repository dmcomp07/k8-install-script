#!/bin/bash

set -e

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect Linux distribution."
    exit 1
fi

echo "Detected OS: $OS"

# Remove Podman to avoid conflict with Docker CLI (optional)
if command -v podman &> /dev/null; then
    echo "Podman detected. Removing Podman to avoid conflicts with Docker..."
    if [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" || "$OS" == "almalinux" ]]; then
        sudo dnf remove -y podman
    elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        sudo apt-get remove -y podman
    else
        echo "Podman removal not supported for this OS in the script."
    fi
fi

# Install dependencies & Docker
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    sudo apt-get update
    sudo apt-get install -y curl git apt-transport-https ca-certificates gnupg lsb-release

    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sudo bash
    fi

elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" || "$OS" == "almalinux" ]]; then
    sudo dnf update -y || sudo yum update -y
    sudo dnf install -y curl git yum-utils

    if ! command -v docker &> /dev/null; then
        sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi

else
    echo "Unsupported OS for this script."
    exit 1
fi

# Enable and start Docker service
if systemctl list-unit-files | grep -q docker.service; then
    sudo systemctl enable docker
    sudo systemctl start docker
else
    echo "Docker service not found. Please verify Docker installation."
    exit 1
fi

# Add current user to Docker group for non-root usage
sudo usermod -aG docker $USER
newgrp docker

# Install KIND CLI
KIND_VERSION="v0.30.0"
curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-$(uname)-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

echo "KIND version installed:"
kind --version

# Create KIND cluster config with 1 master and 2 workers
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

echo "Creating KIND cluster with 1 master and 2 workers..."
kind create cluster --config kind-config.yaml

echo "Cluster created. Existing clusters:"
kind get clusters

echo "Installation and cluster creation complete. Please log out and log back in to apply Docker group permissions."
