# A10 Thunder Kubernetes Connector Charts

Production-ready Helm charts for deploying A10 Thunder Kubernetes Connector (TKC) and load balancer configurations.

## Charts

- **[a10-tkc](a10-tkc/)** - TKC operator for cluster-wide deployment (Platform Engineering)
- **[a10-slb](a10-slb/)** - Per-application load balancer configuration (DevOps Teams)

## Quick Start

### For Platform Engineering Team

```bash
# Install TKC operator (once per cluster)
helm repo add a10 https://yves-nkurunziza.github.io/A10-Helm-Charts
helm install tkc a10/a10-tkc -n kube-system
```

### For DevOps Teams

```bash
# Deploy application load balancer
helm install web-app a10/a10-slb -n production \
  --set virtualServer.ipAddress=172.28.3.20 \
  --set serviceGroup.serviceRef.name=web-service
```

## Documentation

- [Deployment Guide](DEPLOYMENT.md)
- [Architecture](a10-tkc/ARCHITECTURE.md)
- [Changelog](a10-tkc/CHANGELOG.md)

## Repository Structure

```
/
├── a10-tkc/              # TKC operator chart
├── a10-slb/              # SLB configuration chart
├── DEPLOYMENT.md         # Deployment guide
└── .github/workflows/    # CI/CD automation
```

## Development

```bash
# Clone repository
git clone https://github.com/yves-nkurunziza/A10-Helm-Charts.git
cd a10-charts

# Test charts locally
helm lint a10-tkc/
helm lint a10-slb/

# Install from local path
helm install tkc ./a10-tkc -n kube-system
```

## Contributing

This repository follows Helm chart best practices and Kubernetes operator patterns.

## License

Copyright © 2024
