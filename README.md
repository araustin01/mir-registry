# Kubernetes Deployment System

A configuration-driven deployment system for Kubernetes that supports both regular kubectl and microk8s.

## Quick Start

### 1. Initial Setup (Ubuntu)
```bash
# Make setup script executable and run it
chmod +x scripts/setup.sh
./scripts/setup.sh full-setup
```

This will install:
- `yq` (YAML processor)
- `microk8s` (lightweight Kubernetes)
- Enable essential addons
- Make scripts executable

### 2. List Available Deployments
```bash
./scripts/deploy.sh list
```

### 3. Deploy Ollama
```bash
./scripts/deploy.sh ollama deploy
```

### 4. Check Status
```bash
./scripts/k8s-util.sh status
./scripts/deploy.sh ollama status
```

## Scripts Overview

### `deploy.sh` - Main Deployment Script
Configuration-driven deployment system that reads from `configs/deployments.yml`.

**Usage:**
```bash
./scripts/deploy.sh <deployment-name> [action]
```

**Actions:**
- `deploy` (default) - Deploy the application
- `delete` - Remove the deployment
- `status` - Show deployment status
- `logs` - Show logs from deployments
- `list` - List available deployments

**Examples:**
```bash
./scripts/deploy.sh ollama deploy      # Deploy Ollama
./scripts/deploy.sh ollama status     # Check Ollama status
./scripts/deploy.sh ollama logs       # View Ollama logs
./scripts/deploy.sh ollama delete     # Remove Ollama
./scripts/deploy.sh list              # List all deployments
```

### `k8s-util.sh` - Cluster Management Utility
Provides cluster management and troubleshooting commands.

**Usage:**
```bash
./scripts/k8s-util.sh <command>
```

**Commands:**
- `status` - Show cluster overview
- `services` - Show all services and external access points
- `nodes` - Show node IPs for external access
- `resources` - Show resource usage (requires metrics-server)
- `storage` - Show storage information
- `addons` - Show microk8s addon status
- `troubleshoot` - Show troubleshooting information
- `port-forward` - Port forward a service to localhost

**Examples:**
```bash
./scripts/k8s-util.sh status                                    # Cluster overview
./scripts/k8s-util.sh services                                  # All services
./scripts/k8s-util.sh port-forward ollama-service alice 11434   # Port forward Ollama
```

### `setup.sh` - Initial System Setup
Installs and configures the Kubernetes environment.

**Usage:**
```bash
./scripts/setup.sh [command]
```

**Commands:**
- `full-setup` (default) - Complete installation and setup
- `install-deps` - Install only dependencies
- `setup-k8s` - Configure microk8s only
- `verify` - Verify installation

## Configuration System

### Deployment Configuration (`configs/deployments.yml`)
Each deployment is defined with:

```yaml
deployments:
  deployment-name:
    description: "Human readable description"
    namespace: target-namespace
    dependencies:           # Applied first, in order
      - namespaces/namespace.yml
      - configs/config.yml
      - secrets/secret.yml
    resources:             # Applied after dependencies
      - deployments/app.yml
      - services/service.yml
    health_checks:         # Wait for these to be ready
      - deployment: app-deployment
        namespace: target-namespace
    test_commands:         # Run after successful deployment
      - "kubectl get pods -n target-namespace"
```

### Adding New Deployments

1. Create your Kubernetes manifest files in the appropriate `definitions/` subdirectories
2. Add an entry to `configs/deployments.yml` following the pattern above
3. Deploy with `./scripts/deploy.sh your-deployment-name deploy`

## Accessing Deployed Services

### Find External Access Points
```bash
./scripts/k8s-util.sh services    # Shows all services including NodePorts
./scripts/k8s-util.sh nodes       # Shows node IPs
```

### Port Forwarding (Alternative Access)
```bash
./scripts/k8s-util.sh port-forward service-name namespace local-port remote-port
```

### Example: Accessing Ollama
After deploying Ollama, you can access it via:

1. **NodePort** (if your node is accessible):
   ```bash
   # Get node IP
   ./scripts/k8s-util.sh nodes
   # Access Ollama API
   curl http://NODE_IP:30434/api/version
   ```

2. **Port Forwarding**:
   ```bash
   ./scripts/k8s-util.sh port-forward ollama-service alice 11434 11434
   # Then access via localhost
   curl http://localhost:11434/api/version
   ```

3. **CLI Client** (inside cluster):
   ```bash
   microk8s kubectl exec -it deployment/ollama-client -n alice -- ollama list
   microk8s kubectl exec -it deployment/ollama-client -n alice -- ollama pull llama2
   microk8s kubectl exec -it deployment/ollama-client -n alice -- ollama run llama2
   ```

## Troubleshooting

### Check Overall Status
```bash
./scripts/k8s-util.sh status
./scripts/k8s-util.sh troubleshoot
```

### Check Specific Deployment
```bash
./scripts/deploy.sh DEPLOYMENT_NAME status
./scripts/deploy.sh DEPLOYMENT_NAME logs
```

### Common Issues

1. **Pods stuck in Pending**: Usually resource constraints or storage issues
   ```bash
   ./scripts/k8s-util.sh storage  # Check storage
   microk8s kubectl describe pod POD_NAME -n NAMESPACE
   ```

2. **Services not accessible**: Check if NodePort/LoadBalancer is configured
   ```bash
   ./scripts/k8s-util.sh services
   ```

3. **MicroK8s not working**: Check status and restart if needed
   ```bash
   microk8s status
   microk8s stop
   microk8s start
   ```

## Directory Structure

```
kubernetes/
├── configs/
│   └── deployments.yml          # Deployment configurations
├── definitions/                 # Kubernetes manifests
│   ├── namespaces/
│   ├── deployments/
│   ├── services/
│   ├── configs/
│   ├── secrets/
│   ├── claims/
│   └── volumes/
└── scripts/
    ├── setup.sh                 # Initial system setup
    ├── deploy.sh                # Main deployment script
    └── k8s-util.sh              # Cluster management utility
```

## Supported Platforms

- **Primary**: Ubuntu with microk8s
- **Secondary**: Any Linux with standard kubectl

The scripts automatically detect whether to use `microk8s kubectl` or `kubectl` directly.
