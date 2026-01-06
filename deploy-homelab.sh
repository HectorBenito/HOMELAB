#!/usr/bin/env bash

################################################################################
# Talos Proxmox GitOps - Master Deployment Script
#
# This script orchestrates the 3-layer deployment:
# - Layer 1: Infrastructure (Terraform - VMs)
# - Layer 2: Configuration (Ansible - Talos Kubernetes)
# - Layer 3: GitOps (ArgoCD + Applications)
#
# Usage: ./deploy-homelab.sh [--skip-layer1] [--skip-layer2] [--skip-layer3] [--destroy-homelab] [--help]
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"
GITOPS_DIR="${SCRIPT_DIR}/gitops"
KUBECONFIG_PATH="${SCRIPT_DIR}/talos-nasbenito/rendered/kubeconfig"

# Layer control flags
DESTROY_HOMELAB=false
SKIP_LAYER1=false
SKIP_LAYER2=false
SKIP_LAYER3=false

# Prerequisite check flags
TERRAFORM_INSTALLED=true
ANSIBLE_INSTALLED=true  
KUBECTL_INSTALLED=true
TALOSCTL_INSTALLED=true
HELM_INSTALLED=true
PYTHON_INSTALLED=true
AGE_INSTALLED=true
SOPS_INSTALLED=true
CLOUDFLARED_INSTALLED=true

# Parse arguments
for arg in "$@"; do
    case $arg in
        --skip-layer1)
            SKIP_LAYER1=true
            shift
            ;;
        --skip-layer2)
            SKIP_LAYER2=true
            shift
            ;;
        --skip-layer3)
            SKIP_LAYER3=true
            shift
            ;;
        --destroy-homelab)
            DESTROY_HOMELAB=true
            shift
            ;;
        --help)
            cat << EOF
Talos Proxmox GitOps - Master Deployment Script

Usage: $0 [OPTIONS]

Options:
  --skip-layer1    Skip Layer 1 (Infrastructure deployment)
  --skip-layer2    Skip Layer 2 (Talos configuration)
  --skip-layer3    Skip Layer 3 (GitOps deployment)
  --destroy-homelab  Destroy the entire homelab deployment
  --help           Show this help message

Layers:
  Layer 1: Infrastructure (Terraform - Talos VMs)
  Layer 2: Configuration (Ansible - Talos Kubernetes)
  Layer 3: GitOps (ArgoCD + Applications)

  NFS: Uses external TrueNas server at 192.168.100.11 (not managed by this script)

EOF
            exit 0
            ;;
    esac
done

# Functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*"
}

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $*"
}

log_layer() {
    echo -e "${MAGENTA}[$(date +'%Y-%m-%d %H:%M:%S')] LAYER:${NC} $*"
}

print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║           TALOS PROXMOX GITOPS DEPLOYMENT                    ║
║                  Single-Click Homelab                        ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

install_tools() {
    log "Installing missing tools..."

    if [ "$TERRAFORM_INSTALLED" = false ]; then
        log "Installing Terraform..."
        # Installation commands for Terraform
        wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update && sudo apt install terraform -y
    fi

    if [ "$ANSIBLE_INSTALLED" = false ]; then
        log "Installing Ansible..."
        # Installation commands for Ansible
        sudo apt install software-properties-common -y
        sudo add-apt-repository --yes --update ppa:ansible/ansible
        sudo apt install ansible -y
    fi

    if [ "$KUBECTL_INSTALLED" = false ]; then
        log "Installing kubectl..."
        # Installation commands for kubectl
        sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
        sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
        sudo apt-get update && sudo apt-get install -y kubectl
    fi

    if [ "$TALOSCTL_INSTALLED" = false ]; then
        log "Installing talosctl..."
        # Installation commands for talosctl
        curl -sL https://talos.dev/install | sh
    fi

    if [ "$HELM_INSTALLED" = false ]; then
        log "Installing Helm..."
        # Installation commands for Helm
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi

    if [ "$PYTHON_INSTALLED" = false ]; then
        log "Installing Python3..."
        # Installation commands for Python3
        sudo apt install -y python3-pip python3-full python3-venv
        python3 -m venv ~/venvs/ansible
        source ~/venvs/ansible/bin/activate
        pip install --upgrade pip
        pip install ansible kubernetes openshift
    fi

    if [ "$AGE_INSTALLED" = false ]; then
        log "Installing age..."
        # Installation commands for age
        sudo apt install -y age
    fi

    if [ "$SOPS_INSTALLED" = false ]; then
        log "Installing SOPS..."
        # Installation commands for SOPS
        SOPS_LATEST_VERSION=$(curl -s "https://api.github.com/repos/getsops/sops/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+')
        curl -Lo sops.deb "https://github.com/getsops/sops/releases/download/v${SOPS_LATEST_VERSION}/sops_${SOPS_LATEST_VERSION}_amd64.deb"
        sudo apt --fix-broken install ./sops.deb
        rm -rf sops.deb
    fi

    if [ "$CLOUDFLARED_INSTALLED" = false ]; then
        log "Installing Cloudflared..."
        # Installation commands for Cloudflared
        # 1. Download the Cloudflare GPG key and add it to your system's keyring
        curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloudflare-archive-keyring.gpg
        # 2. Add the Cloudflare repository to your APT sources
        echo "deb [signed-by=/usr/share/keyrings/cloudflare-archive-keyring.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
        # 3. Update your package list and install cloudflared
        sudo apt update
        sudo apt install cloudflared -y
    fi
}

check_prerequisites() {
    log "Checking prerequisites..."

    local missing_tools=()

    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
        TERRAFORM_INSTALLED=false
    fi

    # Check Ansible
    if ! command -v ansible-playbook &> /dev/null; then
        missing_tools+=("ansible")
        ANSIBLE_INSTALLED=false
    fi

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
        KUBECTL_INSTALLED=false
    fi

    # Check talosctl
    if ! command -v talosctl &> /dev/null; then
        missing_tools+=("talosctl")
        TALOSCTL_INSTALLED=false
    fi

    # Check helm
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
        HELM_INSTALLED=false
    fi

    # Check python3
    if ! python3 - <<'EOF' &> /dev/null; then
import kubernetes
print(kubernetes.__version__)
EOF
        PYTHON_INSTALLED=false
    fi

    # Check age
    if ! command -v age &> /dev/null; then
        missing_tools+=("age")
        AGE_INSTALLED=false
    fi

    # Check SOPS
    if ! command -v sops &> /dev/null; then
        missing_tools+=("sops")
        SOPS_INSTALLED=false
    fi

    # Check Cloudflared
    if ! command -v cloudflared &> /dev/null; then
        missing_tools+=("cloudflared")
        CLOUDFLARED_INSTALLED=false
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install them before continuing"
        echo
        read -p "¿Want to automatically install them Y/N ?" -n 1 -r
        echo  
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            install_tools
        else
            exit 1
        fi      
    fi

    log "✓ All prerequisites installed"
}

destroy_homelab() {
    if [ "$DESTROY_HOMELAB" = false ]; then
        return 0
    fi

    log_warning "Destroying the entire homelab deployment ..."

    read -p "¿Are you sure you want to destroy the entire homelab Y/N ?" -n 1 -r
    echo  
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        cd "${TERRAFORM_DIR}"

        terraform destroy -var-file="${TERRAFORM_DIR}/vm-configs.tfvars" -auto-approve

        log "Homelab destroyed successfully."

        exit 0
    else
        exit 1
    fi      
}

# Layer 1: Infrastructure
layer1_infrastructure() {
    if [ "$SKIP_LAYER1" = true ]; then
        log_warning "Skipping Layer 1 (Infrastructure)"
        return 0
    fi

    log_layer "Starting Layer 1: Infrastructure Deployment"

    cd "${TERRAFORM_DIR}"

    log "Initializing Terraform..."
    terraform init

    log "Validating Terraform configuration..."
    terraform validate

    log "Planning infrastructure changes..."
    terraform plan -out=tfplan -var-file="${TERRAFORM_DIR}/vm-configs.tfvars"

    log "Applying infrastructure..."
    terraform apply tfplan

    log "✅ Layer 1 Complete: Infrastructure deployed"
    echo "VMs Created"

    # Wait for VMs to boot
    log "Waiting for VMs to boot (60 seconds)..."
    sleep 60

    log "Checking VM connectivity..."
    for ip in 192.168.110.18 192.168.110.20 192.168.110.22 192.168.110.19 192.168.110.21 192.168.110.23; do
        if ! timeout 300 bash -c "until ping -c 1 $ip &>/dev/null; do sleep 5; done"; then
            log_error "VM $ip is not reachable"
            exit 1
        fi
    done
    log "✓ All VMs are reachable"
}

# Layer 2: Configuration
layer2_configuration() {
    if [ "$SKIP_LAYER2" = true ]; then
        log_warning "Skipping Layer 2 (Configuration)"
        return 0
    fi

    log_layer "Starting Layer 2: Configuration (Talos Kubernetes)"

    cd "${ANSIBLE_DIR}"

    log "Running Ansible configuration (Talos)..."
    if ! ansible-playbook -i inventory.yml playbooks/talos-setup.yml; then
        log_error "Layer 2 failed - Talos VMs have been cleaned up"
        exit 1
    fi

    log "✅ Layer 2 Complete: Configuration applied"
    echo "  - NFS: Using external TrueNas server at 192.168.100.11"
    echo "  - Talos Kubernetes cluster ready"
    echo "  - Cilium CNI installed"
    echo "  - Kubeconfig: ${KUBECONFIG_PATH}"
}

# Layer 3: GitOps
layer3_gitops() {
    if [ "$SKIP_LAYER3" = true ]; then
        log_warning "Skipping Layer 3 (GitOps)"
        return 0
    fi

    log_layer "Starting Layer 3: GitOps (ArgoCD + Applications)"

    cd "${ANSIBLE_DIR}"

    log "Running Ansible GitOps deployment..."
    if ! ansible-playbook playbooks/flux-bootstrap.yml; then
        log_error "Layer 3 failed - GitOps deployment unsuccessful"
        exit 1
    fi

    log "✅ Layer 3 Complete: GitOps applications deployed"
    echo ""
    echo "ArgoCD Access:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  Admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

# Main deployment function
main() {
    print_banner

    log "Starting Talos Proxmox GitOps deployment..."
    echo ""

    check_prerequisites
    destroy_homelab

    echo ""
    log_info "Deployment plan:"
    echo "  Layer 1: ${SKIP_LAYER1:-Run} Infrastructure"
    echo "  Layer 2: ${SKIP_LAYER2:-Run} Configuration"
    echo "  Layer 3: ${SKIP_LAYER3:-Run} GitOps"
    echo ""

    # Execute layers
    layer1_infrastructure
    layer2_configuration
    layer3_gitops

    # Final summary
    echo ""
    echo -e "${GREEN}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║           DEPLOYMENT COMPLETED SUCCESSFULLY!                 ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    log "🎉 Full homelab deployment complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Export kubeconfig: export KUBECONFIG=${KUBECONFIG_PATH}"
    echo "  2. Access ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  3. Monitor applications: kubectl get applications -n argocd --watch"
}

# Execute main function
main "$@"