#!/bin/bash

set -euo pipefail

# Helper to print messages with timestamp
function info {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

# Detect OS and package manager
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "[ERROR] Cannot detect Linux distribution." >&2
    exit 1
fi

info "Detected OS: $OS"

if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    PKG_UPDATE="sudo apt-get update -y"
    PKG_INSTALL="sudo apt-get install -y"
elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" || "$OS" == "almalinux" ]]; then
    if command -v dnf &> /dev/null; then
        PKG_UPDATE="sudo dnf makecache"
        PKG_INSTALL="sudo dnf install -y"
    else
        PKG_UPDATE="sudo yum makecache"
        PKG_INSTALL="sudo yum install -y"
    fi
else
    echo "[ERROR] Unsupported Linux distribution: $OS" >&2
    exit 1
fi

# Remove Podman to avoid Docker CLI conflict
if command -v podman &> /dev/null; then
    info "Removing Podman to prevent Docker conflicts"
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        sudo apt-get remove -y podman || true
    else
        sudo $PKG_INSTALL podman || sudo dnf remove -y podman || sudo yum remove -y podman || true
    fi
fi

# Update repos
info "Updating package repositories"
$PKG_UPDATE

# Ensure curl and git installed
for pkg in curl git; do
    if ! command -v $pkg &> /dev/null; then
        info "Installing $pkg"
        $PKG_INSTALL $pkg
    else
        info "$pkg already installed"
    fi
done

# Docker install if missing
if ! command -v docker &> /dev/null; then
    info "Installing Docker"
    curl -fsSL https://get.docker.com | sudo bash
else
    info "Docker already installed"
fi

sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker "$USER" || true
newgrp docker || true

# kubelet install if missing
if ! command -v kubelet &> /dev/null; then
    info "Installing kubelet"
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
        echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
        sudo apt-get update
        sudo apt-get install -y kubelet
        sudo apt-mark hold kubelet
    else
        sudo tee /etc/yum.repos.d/kubernetes.repo > /dev/null <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
        $PKG_INSTALL kubelet
        sudo systemctl enable kubelet
    fi
else
    info "kubelet already installed"
fi

# Ensure /usr/local/bin in PATH immediately and persistently
if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
    info "Adding /usr/local/bin to PATH in current session and ~/.bashrc"
    export PATH="$PATH:/usr/local/bin"
    if ! grep -q '/usr/local/bin' "$HOME/.bashrc"; then
        echo 'export PATH=$PATH:/usr/local/bin' >> "$HOME/.bashrc"
    fi
fi

# Install latest KIND
KIND_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
info "Installing KIND v$KIND_VERSION"
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-$(uname -s)-amd64"
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

if ! kind --version &> /dev/null; then
    echo "[ERROR] KIND installation failed" >&2
    exit 1
fi
info "KIND installed: $(kind --version)"

# Install latest kubectl
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
info "Installing kubectl v$KUBECTL_VERSION"
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

if ! kubectl version --client &> /dev/null; then
    echo "[ERROR] kubectl installation failed" >&2
    exit 1
fi
info "kubectl installed: $(kubectl version --client --short)"

# Create KIND cluster configuration (1 master, 2 workers)
cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# Create the cluster with timeout wait
info "Creating KIND cluster (1 master + 2 workers)..."
kind create cluster --config kind-config.yaml --wait 5m

info "Waiting for all nodes to be 'Ready'..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

info "Cluster nodes:"
kubectl get nodes

info "KIND Kubernetes dev environment setup complete!"
info "You may need to log out and log back in for Docker group perms and PATH changes."
