#!/usr/bin/env bash
set -euo pipefail
#-------------
# curl -O https://your-server/install-kind.sh   # or save script manually
# chmod +x install-kind.sh
# sudo ./install-kind.sh

# optional version overrides:
# sudo KIND_VERSION=v0.31.0 KUBECTL_VERSION=v1.31.0 ./install-kind.sh

#--------------------------------------------------
# Config
#--------------------------------------------------
KIND_VERSION_DEFAULT="v0.30.0"   # change if needed
KUBECTL_VERSION_DEFAULT="v1.30.0"

# Allow overrides via env
KIND_VERSION="${KIND_VERSION:-$KIND_VERSION_DEFAULT}"
KUBECTL_VERSION="${KUBECTL_VERSION:-$KUBECTL_VERSION_DEFAULT}"

#--------------------------------------------------
# Helpers
#--------------------------------------------------
log()  { printf "\033[1;32m[INFO]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    err "Run as root or with sudo."
    exit 1
  fi
}

detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID=${ID,,}
    OS_LIKE=${ID_LIKE:-}
  else
    err "Cannot detect OS (no /etc/os-release)."
    exit 1
  fi
}

arch_map() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l) echo "arm" ;;
    *) err "Unsupported architecture: $arch"; exit 1 ;;
  esac
}

install_docker_debian() {
  log "Installing Docker (Debian/Ubuntu family)..."
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/"$OS_ID"/gpg -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_ID \
    $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker || true
}

install_docker_rhel() {
  log "Installing Docker (RHEL/CentOS/Rocky/Alma)..."
  yum install -y yum-utils ca-certificates curl
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker || true
}

install_docker_fedora() {
  log "Installing Docker (Fedora)..."
  dnf -y install dnf-plugins-core ca-certificates curl
  dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
  dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker || true
}

install_docker_suse() {
  log "Installing Docker (openSUSE)..."
  zypper refresh
  zypper install -y docker
  systemctl enable --now docker || true
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker already installed."
    return
  fi

  case "$OS_ID" in
    ubuntu|debian)
      install_docker_debian
      ;;
    rhel|centos|rocky|almalinux)
      install_docker_rhel
      ;;
    fedora)
      install_docker_fedora
      ;;
    opensuse*|sles|suse)
      install_docker_suse
      ;;
    *)
      # Try by family if ID is unusual
      if [[ "$OS_LIKE" == *"debian"* ]]; then
        install_docker_debian
      elif [[ "$OS_LIKE" == *"rhel"* ]]; then
        install_docker_rhel
      elif [[ "$OS_LIKE" == *"suse"* ]]; then
        install_docker_suse
      else
        warn "Unknown distro; attempting generic Docker install via convenience script."
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker || true
      fi
      ;;
  esac
}

install_kind_binary() {
  local arch os
  os="linux"
  arch="$(arch_map)"

  if command -v kind >/dev/null 2>&1; then
    log "KIND already installed at $(command -v kind)."
    return
  fi

  log "Installing KIND ${KIND_VERSION} for ${os}/${arch}..."
  curl -Lo /usr/local/bin/kind \
    "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-${os}-${arch}"
  chmod +x /usr/local/bin/kind
}

install_kubectl() {
  local arch
  arch="$(arch_map)"

  if command -v kubectl >/dev/null 2>&1; then
    log "kubectl already installed at $(command -v kubectl)."
    return
  fi

  log "Installing kubectl ${KUBECTL_VERSION}..."
  curl -Lo /usr/local/bin/kubectl \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${arch}/kubectl"
  chmod +x /usr/local/bin/kubectl
}

create_kind_cluster() {
  if kind get clusters | grep -q "^kind$"; then
    log "KIND cluster 'kind' already exists, skipping creation."
    return
  fi

  log "Creating default KIND cluster named 'kind'..."
  kind create cluster --name kind
}

post_info() {
  log "Installation complete."
  log "Binary locations:"
  log "  kind:    $(command -v kind || echo 'not found')"
  log "  kubectl: $(command -v kubectl || echo 'not found')"
  log "Current clusters:"
  kind get clusters || true
  log "Try: kubectl get nodes"
}

#--------------------------------------------------
# Main
#--------------------------------------------------
require_root
detect_os

log "Detected OS: ${OS_ID} (like: ${OS_LIKE:-unknown})"
log "Target KIND version: ${KIND_VERSION}"
log "Target kubectl version: ${KUBECTL_VERSION}"

install_docker
install_kind_binary
install_kubectl
create_kind_cluster
post_info
