# A10 SLB Configuration

Helm chart for deploying A10 Thunder load balancer configuration resources.

## Overview

This chart creates CRD instances for per-application load balancer configuration:
- **HealthMonitor**: Health check definitions
- **ServiceGroup**: Backend server pools with load balancing
- **VirtualServer**: Frontend VIP addresses  
- **VirtualPort**: Port and protocol bindings

## Prerequisites

- `a10-tkc` operator must be installed first (by Platform Engineering)
- Target Kubernetes Service must exist
- Virtual IP address allocated

## Installation

### Simple: Use Values File

```bash
# Use default values
helm install web-app ../a10-slb -n production

# Or use custom values file
helm install web-app ../a10-slb -n production -f my-app.yaml
```

### Using Example Configurations

```bash
# Web application (HTTP on port 80)
helm install web-app ../a10-slb -n production \
  -f examples/web-app.yaml

# API application (HTTPS on port 443)
helm install api-app ../a10-slb -n production \
  -f examples/api-app.yaml
```

### Command Line Overrides (if needed)

```bash
helm install web-app ../a10-slb -n production \
  --set virtualServer.ipAddress=172.28.3.22 \
  --set serviceGroup.serviceRef.name=my-service
```

## Configuration

See [examples/](examples/) directory for ready-to-use configurations.

### Basic Structure

```yaml
virtualServer:
  ipAddress: "172.28.3.20"  # Your VIP

serviceGroup:
  serviceRef:
    name: "your-k8s-service"
    namespace: "your-namespace"
```

## Examples

- [examples/web-app.yaml](examples/web-app.yaml) - HTTP web application
- [examples/api-app.yaml](examples/api-app.yaml) - HTTPS API service

## Team Workflow

**Platform Engineering deploys TKC once:**
```bash
cd /Users/yvesnkurunziza/A10/a10-tkc
helm install tkc . -n kube-system
```

**DevOps teams deploy per application:**
```bash
cd /Users/yvesnkurunziza/A10/a10-slb

# Copy and customize example
cp examples/web-app.yaml my-app.yaml
# Edit my-app.yaml with your settings

# Deploy
helm install my-app . -n production -f my-app.yaml
```

## Upgrading

```bash
helm upgrade web-app ../a10-slb -f my-app.yaml
```

## Uninstalling

```bash
helm uninstall web-app
```

This removes the load balancer configuration but does not affect the TKC operator.
