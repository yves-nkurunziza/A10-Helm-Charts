# Deployment Guide - Real Infrastructure

## Network Topology

```
Management Network: 192.168.122.0/24
├── server01 (k8s control plane): 192.168.122.47
├── server02 (k8s worker):        192.168.122.167
├── server03 (k8s worker):        192.168.122.192
└── A10 Thunder ADC:              192.168.122.211

Data Plane Network: 10.98.252.0/25
├── server01 (k8s control plane): 10.98.252.31
├── server02 (k8s worker):        10.98.252.32
└── server03 (k8s worker):        10.98.252.41
```

## Prerequisites

1. **Thunder ADC Access**
   - Management interface accessible at `192.168.122.211:443`
   - Admin credentials available
   - Partition created (default: `shared`)

2. **Kubernetes Cluster**
   - 3-node cluster with control plane on server01
   - Helm 3.x installed
   - `kubectl` configured

3. **Network Connectivity**
   - Kubernetes nodes can reach `192.168.122.211:443` (Thunder management)
   - Thunder ADC can reach nodes on data plane network `10.98.252.0/25`

## Step 1: Install TKC Operator (Platform Team)

```bash
# From your workstation
cd /Users/yvesnkurunziza/A10/a10-tkc

# Option A: Using production values file
helm install tkc . -n kube-system \
  -f examples/production/values.yaml \
  --set thunder.password='YOUR-ACTUAL-PASSWORD'

# Option B: Command line override
helm install tkc . -n kube-system \
  --set thunder.host=192.168.122.211 \
  --set thunder.password='YOUR-ACTUAL-PASSWORD'
```

### Verify TKC Installation

```bash
# Check pod status
kubectl get pods -n kube-system -l app.kubernetes.io/name=a10-tkc

# Check logs
kubectl logs -n kube-system -l app.kubernetes.io/name=a10-tkc --tail=50

# Verify CRDs installed
kubectl api-resources | grep tkc.a10networks.com

# Run Helm test
helm test tkc -n kube-system
```

## Step 2: Deploy Application Load Balancer (DevOps Team)

```bash
cd /Users/yvesnkurunziza/A10/a10-slb

# Deploy for your application
helm install web-app . -n production \
  --set virtualServer.name=vs-web \
  --set virtualServer.ipAddress=10.98.252.100 \
  --set serviceGroup.name=sg-web \
  --set serviceGroup.serviceRef.name=web-service \
  --set serviceGroup.serviceRef.namespace=production
```

### Virtual IP Assignment

Allocate VIPs from data plane network for Thunder ADC:

```
Available range: 10.98.252.64 - 10.98.252.126
(10.98.252.0/25 minus used IPs)

Example assignments:
- Web app:    10.98.252.100
- API app:    10.98.252.101
- Mobile app: 10.98.252.102
```

### Verify Application Config

```bash
# Check CRD instances
kubectl get healthmonitors,servicegroups,virtualservers,virtualports -n production

# Check TKC reconciliation
kubectl logs -n kube-system -l app.kubernetes.io/name=a10-tkc \
  | grep "Reconciling"

# Test from external client
curl http://10.98.252.100
```

## Troubleshooting

### TKC Can't Reach Thunder ADC

```bash
# Test connectivity from TKC pod
kubectl exec -n kube-system deploy/tkc-a10-tkc -- \
  curl -k https://192.168.122.211:443

# Check NetworkPolicy
kubectl get networkpolicy -n kube-system
```

### Thunder ADC Can't Reach Backend Pods

```bash
# Verify service endpoints
kubectl get endpoints -n production

# Check node IPs
kubectl get nodes -o wide

# Ensure Thunder ADC routes to 10.98.252.0/25
```

### Debug Script

```bash
cd /Users/yvesnkurunziza/A10/a10-tkc/examples/troubleshooting
./debug.sh kube-system tkc
```

## Network Policy Notes

The default NetworkPolicy allows TKC egress to:
- `192.168.122.211/32` (Thunder ADC management)
- Kubernetes API (443, 6443)
- DNS (kube-dns)

If Thunder management IP changes, update NetworkPolicy in values:
```yaml
networkPolicy:
  enabled: true
```

## Next Steps

1. Configure additional applications using `a10-slb` chart
2. Set up monitoring with ServiceMonitor (if using Prometheus)
3. Configure backup/restore for Thunder ADC
4. Implement GitOps for declarative config management
