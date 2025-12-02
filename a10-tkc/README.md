# A10 Thunder Kubernetes Connector (TKC)

Helm chart for deploying the A10 Thunder Kubernetes Connector operator.

📐 **[Architecture Overview](ARCHITECTURE.md)**

## Overview

This chart is deployed **once per cluster** by the **Platform Engineering team**.

For per-application load balancer configuration, see the sibling chart: **[a10-slb](../a10-slb/)**

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- A10 Thunder ADC with HTTPS management access
- Valid Thunder ADC credentials

## Installation

### Platform Engineering: Install TKC Operator

```bash
cd /Users/yvesnkurunziza/A10/a10-tkc
helm install tkc . -n kube-system \
  --set thunder.host=thunder.example.com \
  --set thunder.password=CHANGE-ME
```

### DevOps Teams: Deploy Application Config

```bash
cd /Users/yvesnkurunziza/A10/a10-slb
helm install web-app . -n production \
  --set virtualServer.ipAddress=192.168.10.100 \
  --set serviceGroup.serviceRef.name=web-svc
```

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `thunder.host` | Thunder ADC IP/hostname | `192.168.10.10` |
| `thunder.port` | Thunder management port | `443` |
| `thunder.username` | Thunder  admin username | `admin` |
| `thunder.password` | Thunder admin password | `a10` |
| `thunder.partition` | Thunder partition name | `shared` |
| `tkc.logLevel` | Log level (INFO/DEBUG/WARNING/ERROR) | `INFO` |
| `tkc.watchNamespaces` | Namespaces to watch ([] = all) | `[]` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `512Mi` |
| `podDisruptionBudget.enabled` | Enable PDB | `true` |
| `podDisruptionBudget.minAvailable` | Minimum available pods | `1` |

## Architecture

This chart deploys:
- TKC Deployment (operator/controller)
- ServiceAccount with RBAC
- Secret for Thunder credentials
- CRD definitions
- PodDisruptionBudget

Load balancer configurations are deployed separately using `a10-slb` chart.

## Security

- Runs as non-root user (UID 65534)
- Read-only root filesystem
- Drops all capabilities
- Seccomp profile enabled

## Upgrading

```bash
helm upgrade tkc . --reuse-values
```

## Uninstalling

```bash
helm uninstall tkc
```

**Note:** This does not delete CRDs. Remove manually if needed:

```bash
kubectl delete crd healthmonitors.tkc.a10networks.com
kubectl delete crd servicegroups.tkc.a10networks.com
kubectl delete crd virtualservers.tkc.a10networks.com
kubectl delete crd virtualports.tkc.a10networks.com
```
