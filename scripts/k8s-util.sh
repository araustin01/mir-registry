#!/bin/bash

# Kubernetes cluster management utility
# Supports both kubectl and microk8s

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Determine kubectl command
setup_kubectl() {
    if command -v microk8s &> /dev/null; then
        KUBECTL_CMD="microk8s kubectl"
        print_status "Using microk8s kubectl"
    elif command -v kubectl &> /dev/null; then
        KUBECTL_CMD="kubectl"
        print_status "Using kubectl"
    else
        print_error "Neither microk8s nor kubectl is available."
        exit 1
    fi
}

# Function to show cluster status
cluster_status() {
    print_header "Cluster Status"
    
    print_status "Cluster info:"
    $KUBECTL_CMD cluster-info || true
    echo ""
    
    print_status "Nodes:"
    $KUBECTL_CMD get nodes -o wide || true
    echo ""
    
    print_status "Namespaces:"
    $KUBECTL_CMD get namespaces || true
    echo ""
    
    print_status "All pods across namespaces:"
    $KUBECTL_CMD get pods --all-namespaces || true
}

# Function to show all services with NodePorts
show_services() {
    print_header "Services Overview"
    
    print_status "All services:"
    $KUBECTL_CMD get services --all-namespaces -o wide || true
    echo ""
    
    print_status "NodePort services (external access):"
    $KUBECTL_CMD get services --all-namespaces -o wide | grep NodePort || print_warning "No NodePort services found"
    echo ""
    
    print_status "LoadBalancer services:"
    $KUBECTL_CMD get services --all-namespaces -o wide | grep LoadBalancer || print_warning "No LoadBalancer services found"
}

# Function to get node IPs for external access
get_node_ips() {
    print_header "Node IPs for External Access"
    
    print_status "Internal IPs:"
    $KUBECTL_CMD get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' | tr ' ' '\n'
    echo ""
    
    print_status "External IPs (if available):"
    EXTERNAL_IPS=$($KUBECTL_CMD get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' | tr ' ' '\n')
    if [[ -z "$EXTERNAL_IPS" ]]; then
        print_warning "No external IPs configured"
    else
        echo "$EXTERNAL_IPS"
    fi
}

# Function to show resource usage
resource_usage() {
    print_header "Resource Usage"
    
    if $KUBECTL_CMD top nodes &> /dev/null; then
        print_status "Node resource usage:"
        $KUBECTL_CMD top nodes
        echo ""
        
        print_status "Pod resource usage:"
        $KUBECTL_CMD top pods --all-namespaces
    else
        print_warning "Metrics server not available. Resource usage data unavailable."
        print_status "To enable metrics in microk8s: microk8s enable metrics-server"
    fi
}

# Function to show storage
storage_info() {
    print_header "Storage Information"
    
    print_status "Persistent Volumes:"
    $KUBECTL_CMD get pv || true
    echo ""
    
    print_status "Persistent Volume Claims:"
    $KUBECTL_CMD get pvc --all-namespaces || true
    echo ""
    
    print_status "Storage Classes:"
    $KUBECTL_CMD get storageclass || true
}

# Function to enable/disable microk8s addons
manage_addons() {
    if ! command -v microk8s &> /dev/null; then
        print_error "This function requires microk8s"
        exit 1
    fi
    
    print_header "MicroK8s Addons"
    
    print_status "Current addon status:"
    microk8s status
    echo ""
    
    print_status "Available commands:"
    echo "  Enable DNS: microk8s enable dns"
    echo "  Enable Dashboard: microk8s enable dashboard"
    echo "  Enable Ingress: microk8s enable ingress"
    echo "  Enable MetalLB: microk8s enable metallb"
    echo "  Enable Storage: microk8s enable storage"
    echo "  Enable Metrics: microk8s enable metrics-server"
    echo "  Enable Registry: microk8s enable registry"
}

# Function to troubleshoot common issues
troubleshoot() {
    print_header "Troubleshooting Information"
    
    print_status "Failed pods:"
    $KUBECTL_CMD get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded || true
    echo ""
    
    print_status "Recent events:"
    $KUBECTL_CMD get events --all-namespaces --sort-by='.lastTimestamp' | tail -20 || true
    echo ""
    
    print_status "Resource quotas:"
    $KUBECTL_CMD get resourcequota --all-namespaces || true
    echo ""
    
    if command -v microk8s &> /dev/null; then
        print_status "MicroK8s inspect (last 20 lines):"
        microk8s inspect | tail -20 || true
    fi
}

# Function to port forward a service
port_forward() {
    local service_name="$1"
    local namespace="${2:-default}"
    local local_port="${3:-8080}"
    local remote_port="${4:-80}"
    
    if [[ -z "$service_name" ]]; then
        print_error "Service name is required"
        echo "Usage: $0 port-forward <service-name> [namespace] [local-port] [remote-port]"
        exit 1
    fi
    
    print_status "Port forwarding $service_name:$remote_port to localhost:$local_port"
    print_status "Press Ctrl+C to stop"
    $KUBECTL_CMD port-forward -n "$namespace" "service/$service_name" "$local_port:$remote_port"
}

# Function to show help
show_help() {
    echo "Kubernetes Cluster Management Utility"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status          - Show cluster status overview"
    echo "  services        - Show all services and external access points"
    echo "  nodes           - Show node IPs for external access"
    echo "  resources       - Show resource usage (requires metrics-server)"
    echo "  storage         - Show storage information"
    echo "  addons          - Show microk8s addon status and commands"
    echo "  troubleshoot    - Show troubleshooting information"
    echo "  port-forward    - Port forward a service to localhost"
    echo "  help            - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 services"
    echo "  $0 port-forward ollama-service alice 11434 11434"
}

# Main script logic
main() {
    setup_kubectl
    
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        "status")
            cluster_status
            ;;
        "services")
            show_services
            ;;
        "nodes")
            get_node_ips
            ;;
        "resources")
            resource_usage
            ;;
        "storage")
            storage_info
            ;;
        "addons")
            manage_addons
            ;;
        "troubleshoot")
            troubleshoot
            ;;
        "port-forward")
            port_forward "$@"
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
