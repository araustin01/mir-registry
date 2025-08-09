#!/bin/bash

# Generic Kubernetes deployment script
# Usage: ./deploy.sh <deployment-name> [action]
# Actions: deploy, delete, status, logs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$REPO_ROOT/configs/deployments.yml"

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

# Function to check if dependencies are installed
check_dependencies() {
    if ! command -v yq &> /dev/null; then
        print_error "yq is required but not installed. Please install yq to parse YAML files."
        print_status "Install with: sudo snap install yq"
        exit 1
    fi
    
    # Check for microk8s first, then kubectl
    if command -v microk8s &> /dev/null; then
        KUBECTL_CMD="microk8s kubectl"
        print_status "Using microk8s kubectl"
    elif command -v kubectl &> /dev/null; then
        KUBECTL_CMD="kubectl"
        print_status "Using kubectl"
    else
        print_error "Neither microk8s nor kubectl is available."
        print_status "Install microk8s with: sudo snap install microk8s --classic"
        print_status "Or install kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
        exit 1
    fi
}

# Function to get deployment configuration
get_deployment_config() {
    local deployment_name="$1"
    local field="$2"
    
    yq eval ".deployments.${deployment_name}.${field}" "$CONFIG_FILE" 2>/dev/null
}

# Function to get deployment array
get_deployment_array() {
    local deployment_name="$1"
    local field="$2"
    
    yq eval ".deployments.${deployment_name}.${field}[]" "$CONFIG_FILE" 2>/dev/null
}

# Function to list available deployments
list_deployments() {
    print_header "Available Deployments"
    yq eval '.deployments | keys | .[]' "$CONFIG_FILE" 2>/dev/null | while read -r deployment; do
        description=$(get_deployment_config "$deployment" "description")
        namespace=$(get_deployment_config "$deployment" "namespace")
        echo "  $deployment - $description (namespace: $namespace)"
    done
}

# Function to deploy resources
deploy_deployment() {
    local deployment_name="$1"
    
    print_header "Deploying $deployment_name"
    
    # Check if deployment exists in config
    if ! yq eval ".deployments | has(\"$deployment_name\")" "$CONFIG_FILE" | grep -q "true"; then
        print_error "Deployment '$deployment_name' not found in configuration"
        list_deployments
        exit 1
    fi
    
    local description=$(get_deployment_config "$deployment_name" "description")
    local namespace=$(get_deployment_config "$deployment_name" "namespace")
    
    print_status "Description: $description"
    print_status "Namespace: $namespace"
    
    # Apply dependencies first
    print_status "Applying dependencies..."
    get_deployment_array "$deployment_name" "dependencies" | while read -r dependency; do
        if [[ "$dependency" != "null" && "$dependency" != "" ]]; then
            print_status "  Applying dependency: $dependency"
            $KUBECTL_CMD apply -f "$REPO_ROOT/definitions/$dependency"
        fi
    done
    
    # Apply main resources
    print_status "Applying main resources..."
    get_deployment_array "$deployment_name" "resources" | while read -r resource; do
        if [[ "$resource" != "null" && "$resource" != "" ]]; then
            print_status "  Applying resource: $resource"
            $KUBECTL_CMD apply -f "$REPO_ROOT/definitions/$resource"
        fi
    done
    
    # Wait for health checks
    print_status "Waiting for deployments to be ready..."
    get_deployment_array "$deployment_name" "health_checks" | while read -r check; do
        if [[ "$check" != "null" && "$check" != "" ]]; then
            local dep_name=$(echo "$check" | yq eval '.deployment' -)
            local dep_namespace=$(echo "$check" | yq eval '.namespace' -)
            if [[ "$dep_name" != "null" && "$dep_namespace" != "null" ]]; then
                print_status "  Waiting for deployment/$dep_name in namespace $dep_namespace"
                $KUBECTL_CMD wait --for=condition=available --timeout=300s "deployment/$dep_name" -n "$dep_namespace" || true
            fi
        fi
    done
    
    # Run test commands
    print_status "Running verification commands..."
    get_deployment_array "$deployment_name" "test_commands" | while read -r command; do
        if [[ "$command" != "null" && "$command" != "" ]]; then
            print_status "  Running: $command"
            eval "$command"
        fi
    done
    
    print_header "$deployment_name deployment complete!"
}

# Function to delete deployment
delete_deployment() {
    local deployment_name="$1"
    
    print_header "Deleting $deployment_name"
    
    # Check if deployment exists in config
    if ! yq eval ".deployments | has(\"$deployment_name\")" "$CONFIG_FILE" | grep -q "true"; then
        print_error "Deployment '$deployment_name' not found in configuration"
        exit 1
    fi
    
    # Delete main resources (in reverse order)
    print_status "Deleting main resources..."
    get_deployment_array "$deployment_name" "resources" | tac | while read -r resource; do
        if [[ "$resource" != "null" && "$resource" != "" ]]; then
            print_status "  Deleting resource: $resource"
            $KUBECTL_CMD delete -f "$REPO_ROOT/definitions/$resource" --ignore-not-found=true
        fi
    done
    
    # Delete dependencies (in reverse order)
    print_status "Deleting dependencies..."
    get_deployment_array "$deployment_name" "dependencies" | tac | while read -r dependency; do
        if [[ "$dependency" != "null" && "$dependency" != "" ]]; then
            print_status "  Deleting dependency: $dependency"
            $KUBECTL_CMD delete -f "$REPO_ROOT/definitions/$dependency" --ignore-not-found=true
        fi
    done
    
    print_header "$deployment_name deletion complete!"
}

# Function to show deployment status
show_status() {
    local deployment_name="$1"
    
    print_header "Status for $deployment_name"
    
    local namespace=$(get_deployment_config "$deployment_name" "namespace")
    
    print_status "Pods in namespace $namespace:"
    $KUBECTL_CMD get pods -n "$namespace" || true
    
    print_status "Services in namespace $namespace:"
    $KUBECTL_CMD get services -n "$namespace" || true
    
    print_status "Deployments in namespace $namespace:"
    $KUBECTL_CMD get deployments -n "$namespace" || true
}

# Function to show logs
show_logs() {
    local deployment_name="$1"
    
    print_header "Logs for $deployment_name"
    
    local namespace=$(get_deployment_config "$deployment_name" "namespace")
    
    # Show logs for all deployments in the health_checks
    get_deployment_array "$deployment_name" "health_checks" | while read -r check; do
        if [[ "$check" != "null" && "$check" != "" ]]; then
            local dep_name=$(echo "$check" | yq eval '.deployment' -)
            local dep_namespace=$(echo "$check" | yq eval '.namespace' -)
            if [[ "$dep_name" != "null" && "$dep_namespace" != "null" ]]; then
                print_status "Logs for deployment/$dep_name in namespace $dep_namespace:"
                $KUBECTL_CMD logs "deployment/$dep_name" -n "$dep_namespace" --tail=50 || true
                echo ""
            fi
        fi
    done
}

# Main script logic
main() {
    check_dependencies
    
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <deployment-name> [action]"
        echo "Actions: deploy (default), delete, status, logs, list"
        echo ""
        list_deployments
        exit 1
    fi
    
    local deployment_name="$1"
    local action="${2:-deploy}"
    
    case "$action" in
        "deploy")
            deploy_deployment "$deployment_name"
            ;;
        "delete")
            delete_deployment "$deployment_name"
            ;;
        "status")
            show_status "$deployment_name"
            ;;
        "logs")
            show_logs "$deployment_name"
            ;;
        "list")
            list_deployments
            ;;
        *)
            print_error "Unknown action: $action"
            echo "Available actions: deploy, delete, status, logs, list"
            exit 1
            ;;
    esac
}

main "$@"
