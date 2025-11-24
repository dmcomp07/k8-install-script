#!/bin/bash
set -e

echo "🔍 Detecting OS..."
OS=""
VERSION_CODENAME=""
VERSION_ID=""

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION_CODENAME=${VERSION_CODENAME:-}
    VERSION_ID=${VERSION_ID:-}
else
    echo "❌ Unable to detect OS"
    exit 1
fi

install_dependencies() {
    echo "📦 Installing dependencies..."
    
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        sudo apt update
        sudo apt install -y apt-transport-https ca-certificates curl gnupg software-properties-common
        
        if ! command -v docker &> /dev/null; then
            echo "🐳 Installing Docker..."
            
            # Install Docker GPG key
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg
            
            # Determine codename for Docker repo
            if [ -z "$VERSION_CODENAME" ]; then
                VERSION_CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2 | tr -d '"')
            fi
            
            # Add Docker repository
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
              $VERSION_CODENAME stable" | \
              sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            sudo apt update
            sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        fi
        
    elif [[ "$OS" == "almalinux" || "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "rocky" ]]; then
        sudo yum install -y yum-utils curl ca-certificates
        
        if ! command -v docker &> /dev/null; then
            echo "🐳 Installing Docker..."
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        fi
        
    else
        echo "❌ Unsupported OS: $OS"
        exit 1
    fi
    
    sudo systemctl enable --now docker
    echo "✅ Docker installed and started"
    
    # Add user to docker group
    sudo usermod -aG docker $USER || true
    echo "⚠️  You may need to log out and back in for Docker group permissions to apply"
}

install_kind_kubectl() {
    echo "🔧 Installing kind and kubectl..."
    
    # Install kind (latest stable version)
    KIND_VERSION="v0.24.0"
    curl -Lo kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64
    chmod +x kind
    sudo mv kind /usr/local/bin/kind
    echo "✅ kind ${KIND_VERSION} installed"
    
    # Install kubectl
    KUBECTL_VERSION=$(curl -Ls https://dl.k8s.io/release/stable.txt)
    
    if [[ -z "$KUBECTL_VERSION" ]] || [[ ! "$KUBECTL_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "⚠️  Failed to fetch kubectl version. Using fallback v1.31.0"
        KUBECTL_VERSION="v1.31.0"
    else
        echo "✅ kubectl version: $KUBECTL_VERSION"
    fi
    
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
    echo "✅ kubectl ${KUBECTL_VERSION} installed"
}

create_kind_cluster() {
    echo "🧱 Creating kind cluster with 1 control-plane and 2 workers..."
    
    cat << EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF
    
    kind create cluster --name dev-cluster --config kind-config.yaml
    echo "✅ kind cluster 'dev-cluster' created"
    
    # Cleanup config file
    rm -f kind-config.yaml
}

main() {
    install_dependencies
    install_kind_kubectl
    create_kind_cluster
    
    echo ""
    echo "🎉 Setup complete! You can now use kubectl to interact with your cluster."
    echo "📘 Try: kubectl get nodes"
    echo ""
    echo "⚠️  If you see permission errors with docker, run: newgrp docker"
}

main
