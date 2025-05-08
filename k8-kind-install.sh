#!/bin/bash

set -e

echo "🔍 Detecting OS..."
OS=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "❌ Unable to detect OS"
    exit 1
fi

install_dependencies() {
    echo "📦 Installing dependencies..."

    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        sudo apt update
        sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common

        if ! command -v docker &> /dev/null; then
            echo "🐳 Installing Docker..."
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
                | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt update
            sudo apt install -y docker-ce docker-ce-cli containerd.io
        fi

    elif [[ "$OS" == "almalinux" || "$OS" == "centos" || "$OS" == "rhel" ]]; then
        sudo yum install -y yum-utils curl ca-certificates gnupg lsb-release

        if ! command -v docker &> /dev/null; then
            echo "🐳 Installing Docker..."
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io
        fi
    else
        echo "❌ Unsupported OS: $OS"
        exit 1
    fi

    sudo systemctl enable --now docker
    echo "✅ Docker installed and started"

    # Add user to docker group
    sudo usermod -aG docker $USER || true
    echo "⚠️ You may need to log out and back in for Docker group permissions to apply"
}

install_kind_kubectl() {
    echo "🔧 Installing kind and kubectl..."

    curl -Lo kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x kind
    sudo mv kind /usr/local/bin/kind

    KUBECTL_VERSION=$(curl -Ls https://dl.k8s.io/release/stable.txt | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$')
    if [[ -z "$KUBECTL_VERSION" ]]; then
        echo "⚠️ Failed to fetch kubectl version. Using fallback v1.29.0"
        KUBECTL_VERSION="v1.29.0"
    else
        echo "✅ kubectl version: $KUBECTL_VERSION"
    fi

    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
}

create_kind_cluster() {
    echo "🧱 Creating kind cluster with 1 control-plane and 2 workers..."

    cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

    kind create cluster --name dev-cluster --config kind-config.yaml
    echo "✅ kind cluster 'dev-cluster' created"
}

main() {
    install_dependencies
    install_kind_kubectl
    create_kind_cluster

    echo "🎉 Setup complete! You can now use kubectl to interact with your cluster."
    echo "📘 Try: kubectl get nodes"
}

main
