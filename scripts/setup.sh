#!/bin/bash

# Kubernetes cluster setup and dependency installer for Ubuntu
# Supports both microk8s and regular kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "This script should not be run as root for security reasons"
        print_status "Run without sudo - the script will prompt for sudo when needed"
        exit 1
    fi
}

# Function to install yq
install_yq() {
    if command -v yq &> /dev/null; then
        print_status "yq is already installed"
        # Check if it's the snap version and warn about potential issues
        if yq --version | grep -q "snap" || which yq | grep -q "snap"; then
            print_warning "yq is installed via snap which may have file access issues"
            print_status "Consider reinstalling with: $0 reinstall-yq"
        fi
        return 0
    fi
    
    print_status "Installing yq..."
    
    # First try to remove snap version if it exists
    if snap list yq &> /dev/null; then
        print_status "Removing snap version of yq..."
        sudo snap remove yq
    fi
    
    # Install yq using wget and direct binary installation
    print_status "Downloading yq binary..."
    YQ_VERSION="v4.46.1"
    YQ_BINARY="yq_linux_amd64"
    
    wget -O /tmp/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY}"
    chmod +x /tmp/yq
    sudo mv /tmp/yq /usr/local/bin/yq
    
    print_status "yq installed successfully"
}

# Function to reinstall yq (remove snap version and install binary)
reinstall_yq() {
    print_status "Reinstalling yq with binary version..."
    
    # Remove snap version if it exists
    if snap list yq &> /dev/null; then
        print_status "Removing snap version of yq..."
        sudo snap remove yq
    fi
    
    # Remove any existing binary
    if command -v yq &> /dev/null; then
        YQ_PATH=$(which yq)
        if [[ "$YQ_PATH" == "/usr/local/bin/yq" ]]; then
            print_status "Removing existing binary version..."
            sudo rm -f /usr/local/bin/yq
        fi
    fi
    
    # Install fresh binary
    install_yq
}

# Function to install microk8s
install_microk8s() {
    if command -v microk8s &> /dev/null; then
        print_status "microk8s is already installed"
        return 0
    fi
    
    print_status "Installing microk8s..."
    sudo snap install microk8s --classic
    
    print_status "Adding user to microk8s group..."
    sudo usermod -a -G microk8s $USER
    sudo chown -f -R $USER ~/.kube || true
    
    print_warning "You may need to log out and back in for group changes to take effect"
    print_status "Or run: newgrp microk8s"
}

# Function to setup microk8s
setup_microk8s() {
    print_header "Setting up MicroK8s"
    
    print_status "Waiting for microk8s to be ready..."
    microk8s status --wait-ready
    
    print_status "Enabling essential addons..."
    microk8s enable dns
    microk8s enable storage
    microk8s enable ingress
    
    print_status "Optionally enabling other useful addons..."
    read -p "Enable dashboard? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        microk8s enable dashboard
        print_status "Dashboard enabled. Access with: microk8s dashboard-proxy"
    fi
    
    read -p "Enable MetalLB (load balancer)? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Enter IP range for MetalLB (e.g., 192.168.1.240-192.168.1.250):"
        read -r ip_range
        microk8s enable metallb:$ip_range
    fi
    
    read -p "Enable metrics-server (for resource monitoring)? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        microk8s enable metrics-server
    fi
    
    read -p "Enable registry (local container registry)? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        microk8s enable registry
    fi
}

# Function to create kubectl alias
setup_kubectl_alias() {
    print_status "Setting up kubectl alias..."
    
    if command -v microk8s &> /dev/null; then
        echo "alias kubectl='microk8s kubectl'" >> ~/.bashrc
        echo "alias k='microk8s kubectl'" >> ~/.bashrc
        print_status "Added kubectl alias to ~/.bashrc"
        print_status "Run 'source ~/.bashrc' or restart your shell to use the alias"
    fi
}

# Function to make scripts executable
setup_scripts() {
    print_status "Making scripts executable..."
    chmod +x "$(dirname "$0")/deploy.sh"
    chmod +x "$(dirname "$0")/k8s-util.sh"
    chmod +x "$0"
}

# Function to verify installation
verify_installation() {
    print_header "Verifying Installation"
    
    if command -v yq &> /dev/null; then
        print_status "✓ yq is installed: $(yq --version)"
    else
        print_error "✗ yq is not installed"
    fi
    
    if command -v microk8s &> /dev/null; then
        print_status "✓ microk8s is installed"
        
        if microk8s status | grep -q "microk8s is running"; then
            print_status "✓ microk8s is running"
        else
            print_warning "✗ microk8s is not running"
        fi
        
        # Check addons
        print_status "Enabled addons:"
        microk8s status | grep "enabled" || print_warning "No addons enabled"
    else
        print_error "✗ microk8s is not installed"
    fi
    
    if microk8s kubectl version --client &> /dev/null; then
        print_status "✓ kubectl is accessible via microk8s"
    else
        print_warning "✗ kubectl is not accessible"
    fi
}

# Function to show next steps
show_next_steps() {
    print_header "Next Steps"
    
    echo "1. If you just installed microk8s, log out and back in (or run: newgrp microk8s)"
    echo "2. Test the deployment system:"
    echo "   ./deploy.sh list"
    echo "3. Check cluster status:"
    echo "   ./k8s-util.sh status"
    echo "4. Deploy Ollama:"
    echo "   ./deploy.sh ollama deploy"
    echo "5. Check services:"
    echo "   ./k8s-util.sh services"
    echo ""
    echo "Useful commands:"
    echo "   microk8s status                    - Check microk8s status"
    echo "   microk8s kubectl get pods -A      - List all pods"
    echo "   microk8s dashboard-proxy          - Access dashboard (if enabled)"
    echo "   ./k8s-util.sh troubleshoot        - Troubleshoot issues"
}

# Function to show help
show_help() {
    echo "Kubernetes Setup Script for Ubuntu"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  full-setup    - Complete setup (install everything)"
    echo "  install-deps  - Install dependencies (yq, microk8s)"
    echo "  reinstall-yq  - Reinstall yq with binary version (fixes snap issues)"
    echo "  setup-k8s     - Setup and configure microk8s"
    echo "  setup-scripts - Make scripts executable"
    echo "  verify        - Verify installation"
    echo "  help          - Show this help"
    echo ""
    echo "For first-time setup, run: $0 full-setup"
    echo "If experiencing yq file access issues, run: $0 reinstall-yq"
}

# Main function
main() {
    local command="${1:-full-setup}"
    
    case "$command" in
        "full-setup")
            check_root
            print_header "Full Kubernetes Setup"
            install_yq
            install_microk8s
            setup_microk8s
            setup_kubectl_alias
            setup_scripts
            verify_installation
            show_next_steps
            ;;
        "install-deps")
            check_root
            install_yq
            install_microk8s
            ;;
        "reinstall-yq")
            reinstall_yq
            ;;
        "setup-k8s")
            setup_microk8s
            ;;
        "setup-scripts")
            setup_scripts
            ;;
        "verify")
            verify_installation
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
