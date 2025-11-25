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

```bash
helm install web-app ../a10-slb \
  --set virtualServer.ipAddress=192.168.10.100 \
  --set serviceGroup.serviceRef.name=web-app-svc \
  --set serviceGroup.serviceRef.namespace=default
```

## Configuration

### Health Monitor

```yaml
healthMonitor:
  enabled: true
  name: "hm-http"
  type: "http"
  interval: 5
  timeout: 3
  retry: 3
  method: "GET"
  url: "/"
  statusCode: 200
```

### Service Group

```yaml
serviceGroup:
  enabled: true
  name: "sg-web"
  protocol: "tcp"
  lbMethod: "round-robin"
  serviceRef:
    name: "web-app-svc"
    namespace: "default"
  healthMonitor: "hm-http"
```

### Virtual Server

```yaml
virtualServer:
  enabled: true
  name: "vs-web"
  ipAddress: "192.168.10.100"
```

### Virtual Port

```yaml
virtualPort:
  enabled: true
  name: "vport-80"
  port: 80
  protocol: "http"
  serviceGroup: "sg-web"
  virtualServerName: "vs-web"
  enableDisableAction: "enable"
```

## Team Workflow

**Platform Engineering deploys TKC once:**
```bash
cd /Users/yvesnkurunziza/A10/a10-tkc
helm install tkc . -n kube-system
```

**DevOps teams deploy per application:**
```bash
cd /Users/yvesnkurunziza/A10/a10-slb
helm install my-app . -n my-namespace \
  -f my-app-values.yaml
```

## Upgrading

```bash
helm upgrade web-app ../a10-slb --reuse-values
```

## Uninstalling

```bash
helm uninstall web-app
```

This removes the load balancer configuration but does not affect the TKC operator.
