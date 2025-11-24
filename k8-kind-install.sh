#!/bin/bash

set -e

# Function to print error messages and exit
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Detect OS and package manager
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    error_exit "Cannot detect Linux distribution."
fi

echo "Detected OS: $OS"

# Determine package manager commands
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    PKG_UPDATE="sudo apt-get update -y"
    PKG_INSTALL="sudo apt-get install -y"
    PKG_CHECK="dpkg -s"
elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" || "$OS" == "almalinux" ]]; then
    # Use dnf if available otherwise yum
    if command -v dnf &> /dev/null; then
        PKG_UPDATE="sudo dnf makecache"
        PKG_INSTALL="sudo dnf install -y"
        PKG_CHECK="rpm -q"
    else
        PKG_UPDATE="sudo yum makecache"
        PKG_INSTALL="sudo yum install -y"
        PKG_CHECK="rpm -q"
    fi
else
    error_exit "Unsupported OS."
fi

# Remove Podman if installed to avoid Docker CLI conflicts
if command -v podman &> /dev/null; then
    echo "Podman detected. Removing Podman to avoid conflicts with Docker..."
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        sudo apt-get remove -y podman
    else
        sudo $PKG_INSTALL podman || sudo $PKG_INSTALL -y podman || sudo dnf remove -y podman
    fi
fi

# Update repositories
echo "Updating package repositories..."
$PKG_UPDATE

# Check and install dependencies: curl, git
for tool in curl git; do
    if ! command -v $tool &> /dev/null; then
        echo "Installing $tool..."
        $PKG_INSTALL $tool
    else
        echo "$tool already installed."
    fi
done

# Check and install Docker (dependency of kind)
if ! command -v docker &> /dev/null; then
    echo "Docker is not found. Installing Docker..."
    curl -fsSL https://get.docker.com | sudo bash
else
    echo "Docker already installed."
fi

# Enable and start Docker service
if systemctl list-unit-files | grep -q docker.service; then
    echo "Enabling and starting Docker service..."
    sudo systemctl enable docker
    sudo systemctl start docker
else
    error_exit "Docker service not found after install."
fi

# Add current user to docker group to allow non-root docker usage
sudo usermod -aG docker $USER
newgrp docker || true

# Check if kubelet is installed; install if missing
if ! command -v kubelet &> /dev/null; then
    echo "kubelet is missing. Installing kubelet..."
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
        echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
        sudo apt-get update
        sudo apt-get install -y kubelet
        sudo apt-mark hold kubelet
    elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" || "$OS" == "almalinux" ]]; then
        cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
        sudo $PKG_INSTALL kubelet
        sudo systemctl enable kubelet
    else
        error_exit "Unsupported OS for kubelet installation."
    fi
    echo "kubelet installed."
else
    echo "kubelet already installed."
fi

# Ensure /usr/local/bin in PATH for current session and future sessions
if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
    echo "Adding /usr/local/bin to PATH for this session"
    export PATH=$PATH:/usr/local/bin
    if [[ -f $HOME/.bashrc ]]; then
        echo 'export PATH=$PATH:/usr/local/bin' >> $HOME/.bashrc
    fi
fi

# Fetch latest KIND version if not specified
KIND_VERSION=${KIND_VERSION:-$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')}
echo "Installing KIND version: $KIND_VERSION"
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-$(uname -s)-amd64"
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Confirm KIND install
if ! command -v kind &> /dev/null; then
    error_exit "Kind installation failed!"
else
    echo "Kind installed: $(kind --version)"
fi

# Fetch latest kubectl version if not specified
KUBECTL_VERSION=${KUBECTL_VERSION:-$(curl -L -s https://dl.k8s.io/release/stable.txt)}
echo "Installing kubectl version: $KUBECTL_VERSION"
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

# Confirm kubectl install
if ! command -v kubectl &> /dev/null; then
    error_exit "kubectl installation failed!"
else
    echo "kubectl installed: $(kubectl version --client --short)"
fi

# Create KIND cluster configuration (1 master + 2 workers)
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

# Create the cluster
echo "Creating KIND cluster with 1 master and 2 workers..."
kind create cluster --config kind-config.yaml --wait 5m

# Validate cluster nodes
echo "Waiting for nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "Cluster nodes status:"
kubectl get nodes

echo "KIND Kubernetes environment setup is complete!"
echo "If you face issues with Docker permissions, please log out and log back in."
