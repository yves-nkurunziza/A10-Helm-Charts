# A10 Thunder Kubernetes Connector Helm Charts

Production-ready Helm charts for deploying A10 Thunder Kubernetes Connector (TKC) and application load balancer configurations.

## Charts

- **[a10-tkc](a10-tkc/)** - TKC operator for cluster-wide deployment
- **[a10-slb](a10-slb/)** - Per-application load balancer configuration

## Quick Start

### 1. Add Helm Repository

```bash
helm repo add a10 https://yves-nkurunziza.github.io/A10-Helm-Charts
helm repo update
```

### 2. Install TKC Operator

Deploy once per cluster to enable A10 Thunder ADC integration:

```bash
helm install tkc a10/a10-tkc -n kube-system \
  --set thunder.host=10.98.252.41 \
  --set thunder.password='YOUR-PASSWORD'
```

### 3. Deploy Application Load Balancer

Create load balancer configuration for your application:

```bash
helm install my-app a10/a10-slb -n production \
  --set virtualServer.ipAddress=172.28.3.20 \
  --set serviceGroup.serviceRef.name=my-service
```

> **Note**: The `virtualServer.ipAddress` parameter defines the VIP that clients use to access your application. Populate this with your allocated IP address.

## Repository Structure

```
A10-Helm-Charts/
├── charts/
│   ├── a10-tkc/              # TKC operator chart
│   └── a10-slb/              # Application load balancer chart
├── .github/
│   └── workflows/
│       └── release.yaml      # Automated chart publishing
├── DEPLOYMENT.md             # Deployment guide
└── README.md                 # This file
```

## Documentation

- [Deployment Guide](DEPLOYMENT.md) - Step-by-step installation
- [TKC Architecture](a10-tkc/README.md) - Operator design and configuration
- [SLB Configuration](a10-slb/README.md) - Application load balancer setup
- [GitHub Workflow](GITHUB_WORKFLOW.md) - CI/CD automation

## Development

### Local Testing

```bash
# Clone repository
git clone https://github.com/yves-nkurunziza/A10-Helm-Charts.git
cd A10-Helm-Charts

# Lint charts
helm lint charts/a10-tkc/
helm lint charts/a10-slb/

# Test rendering
helm template tkc charts/a10-tkc/
helm template app charts/a10-slb/

# Install from local path
helm install tkc ./charts/a10-tkc -n kube-system --dry-run=client
```

### Chart Versioning

Charts follow Semantic Versioning 2.0.0:
- **MAJOR**: Breaking changes
- **MINOR**: New features, backwards compatible
- **PATCH**: Bug fixes

Version bumps trigger automatic publishing via GitHub Actions.

## Features

### TKC Operator (a10-tkc)
- ✅ Automated Thunder ADC configuration via aXAPI
- ✅ Kubernetes CRD support (VirtualServer, ServiceGroup, etc.)
- ✅ RBAC with principle of least privilege
- ✅ Network policies for secure communication
- ✅ ConfigMap-based Thunder ADC credentials
- ✅ Health checks and liveness probes

### Application Load Balancer (a10-slb)
- ✅ Parameterized VirtualServer configuration
- ✅ ServiceGroup with backend service reference
- ✅ Health monitor templates (HTTP, HTTPS, TCP)
- ✅ Customizable load balancing methods
- ✅ GitOps-friendly value files

## Support

For issues or questions:
1. Check [Deployment Guide](DEPLOYMENT.md)
2. Review TKC logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=a10-tkc`
3. Validate CRDs: `kubectl get virtualservers,servicegroups,healthmonitors -A`

## License

Copyright © 2025
