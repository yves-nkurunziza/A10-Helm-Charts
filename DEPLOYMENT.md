# Deployment Guide

## Network Topology

```
Management Network: 192.168.122.0/24
├── server01 (k8s control plane): 192.168.122.47
├── server02 (k8s worker):        192.168.122.167
├── server03 (k8s worker):        192.168.122.33
└── A10 Thunder ADC (Mgmt):       192.168.122.200

Data Plane Network: 10.98.252.0/25
├── server01 (k8s control plane): 10.98.252.31
├── server02 (k8s worker):        10.98.252.32
├── server03 (k8s worker):        10.98.252.33
└── A10 Thunder ADC (Data):       10.98.252.40
```

## Prerequisites

### 1. Thunder ADC Requirements
- **Management Access**: `https://192.168.122.200` or `https://10.98.252.40`
- **Admin Credentials**: Username and password with partition access
- **Partition**: `shared` (default) or custom partition created
- **aXAPI Enabled**: REST API accessible on port 443

### 2. Kubernetes Cluster
- **Version**: 1.24+ recommended
- **Helm**: Version 3.8+
- **kubectl**: Configured with cluster admin access
- **Nodes**: At least 3 nodes for high availability

### 3. Network Connectivity
- ✅ Kubernetes nodes → Thunder ADC management IP (`10.98.252.40:443`)
- ✅ Thunder ADC → Kubernetes nodes on data plane (`10.98.252.0/25`)
- ✅ DNS resolution between all components

## Installation

### Step 1: Add Helm Repository

```bash
helm repo add a10 https://yves-nkurunziza.github.io/A10-Helm-Charts
helm repo update
```

### Step 2: Install TKC Operator

The TKC operator runs in `kube-system` namespace and connects to Thunder ADC to configure load balancers based on Kubernetes CRDs.

```bash
# Install with inline values
helm install tkc a10/a10-tkc -n kube-system \
  --set thunder.host=10.98.252.40 \
  --set thunder.username=admin \
  --set thunder.password='Clezionh25!1' \
  --set thunder.partition=shared

# Or use a values file
cat > tkc-values.yaml <<EOF
thunder:
  host: 10.98.252.40
  port: 443
  protocol: https
  username: admin
  password: Clezionh25!1
  partition: shared

image:
  repository: a10networks/a10-kubernetes-connector
  tag: latest
  pullPolicy: IfNotPresent

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

networkPolicy:
  enabled: true
EOF

helm install tkc a10/a10-tkc -n kube-system -f tkc-values.yaml
```

### Step 3: Verify TKC Installation

```bash
# Check pod status
kubectl get pods -n kube-system -l app.kubernetes.io/name=a10-tkc

# Expected output:
# NAME                           READY   STATUS    RESTARTS   AGE
# tkc-a10-tkc-xxxxx-xxxxx        1/1     Running   0          2m

# Check TKC logs for successful Thunder connection
kubectl logs -n kube-system -l app.kubernetes.io/name=a10-tkc --tail=100 | grep "Detect device"

# Expected: "Detect device https://10.98.252.40/axapi/v3: ... is up"

# Verify CRDs are installed
kubectl api-resources | grep tkc.a10networks.com

# Expected output:
# healthmonitors      tkc.a10networks.com       true    HealthMonitor
# servicegroups       tkc.a10networks.com       true    ServiceGroup
# virtualservers      tkc.a10networks.com       true    VirtualServer
# virtualports        tkc.a10networks.com       true    VirtualPort
```

### Step 4: Deploy Your Application

First, ensure your application is running in Kubernetes:

```bash
# Example: Deploy a test nginx application
kubectl create namespace production
kubectl create deployment web-service --image=nginx -n production
kubectl expose deployment web-service --port=80 -n production

# Verify service exists
kubectl get svc web-service -n production
```

### Step 5: Deploy Load Balancer Configuration

```bash
# Deploy load balancer for your application
helm install my-app a10/a10-slb -n production \
  --set virtualServer.name=my-vs \
  --set virtualServer.ipAddress=172.28.3.20 \
  --set serviceGroup.name=my-sg \
  --set serviceGroup.serviceRef.name=web-service \
  --set healthMonitor.name=my-hm \
  --set healthMonitor.type=http \
  --set virtualPort.name=my-vport \
  --set virtualPort.port=80 \
  --set virtualPort.protocol=http
```

> **Important**: The `serviceGroup.serviceRef.name` should be **just the service name**, not `namespace/name`. TKC automatically adds the namespace prefix.

### Step 6: Verify Load Balancer

```bash
# Check CRD resources
kubectl get virtualservers,servicegroups,healthmonitors,virtualports -n production

# Expected output showing Active status:
# NAME                               NAME    VIP            STATUS
# virtualserver.../my-vs             my-vs   172.28.3.20    
#
# NAME                               NAME    STATUS   SERVICE       PROTOCOL
# servicegroup.../my-sg              my-sg   Active   web-service   tcp
#
# NAME                               NAME    STATUS   TYPE    URL
# healthmonitor.../my-hm             my-hm   Active   http    /
#
# NAME                               PORT    PROTOCOL STATUS      VIRTUALSERVER
# virtualport.../my-vport            80      http     NoIngress   my-vs

# Check Thunder ADC configuration (via web UI or API)
# Login to https://10.98.252.40
# Navigate to: SLB → Virtual Servers
# Verify "my-vs" appears with VIP 172.28.3.20

# Test the VIP
curl http://172.28.3.20
# Should return nginx welcome page
```

## VIP Address Planning

Allocate Virtual IP addresses from your data plane network or designated VIP pool:

```yaml
Example Allocations:
  DNS Services:       172.28.3.20
  Web Applications:   172.28.3.50-59
  API Gateways:       172.28.3.100-109
  Internal Services:  172.28.3.200-209
```

> **Note**: Update the `virtualServer.ipAddress` parameter for each application with your allocated VIP.

## Troubleshooting

### Issue: TKC Can't Connect to Thunder ADC

```bash
# Test connectivity from TKC pod
TKC_POD=$(kubectl get pod -n kube-system -l app.kubernetes.io/name=a10-tkc -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n kube-system $TKC_POD -- curl -k https://10.98.252.40/axapi/v3

# Check NetworkPolicy isn't blocking
kubectl get networkpolicy -n kube-system

# Verify Thunder credentials secret
kubectl get secret tkc-a10-tkc-secret -n kube-system -o yaml
```

### Issue: Service Group Shows "NoSvc" Status

```bash
# Verify backend service exists
kubectl get svc -n production

# Check service name matches CRD
kubectl describe servicegroup my-sg -n production

# Common fix: Ensure serviceRef.name is ONLY the service name (no namespace prefix)
```

### Issue: Virtual Server Down on Thunder ADC

```bash
# Check ServiceGroup has backend members
kubectl describe servicegroup my-sg -n production

# Verify pods are running
kubectl get pods -n production -l app=web-service

# Check health monitor status
kubectl describe healthmonitor my-hm -n production
```

### Debug Commands

```bash
# View all TKC logs
kubectl logs -n kube-system -l app.kubernetes.io/name=a10-tkc --tail=500

# Watch TKC processing resources
kubectl logs -n kube-system -l app.kubernetes.io/name=a10-tkc -f | grep -i "virtualserver\|servicegroup"

# Check RBAC permissions
kubectl auth can-i list servicegroups.tkc.a10networks.com --as=system:serviceaccount:kube-system:tkc-a10-tkc
```

## Upgrade

### Upgrade TKC Operator

```bash
# Update Helm repo
helm repo update

# Check available versions
helm search repo a10/a10-tkc --versions

# Upgrade to latest
helm upgrade tkc a10/a10-tkc -n kube-system
```

### Upgrade Application Load Balancer

```bash
# Upgrade specific deployment
helm upgrade my-app a10/a10-slb -n production -f my-values.yaml
```

## Uninstall

```bash
# Remove application load balancer
helm uninstall my-app -n production

# Remove TKC operator (will NOT delete Thunder ADC config)
helm uninstall tkc -n kube-system

# Clean up CRDs if needed
kubectl delete crd virtualservers.tkc.a10networks.com
kubectl delete crd servicegroups.tkc.a10networks.com
kubectl delete crd healthmonitors.tkc.a10networks.com
kubectl delete crd virtualports.tkc.a10networks.com
```

## Next Steps

1. **GitOps Integration**: Use ArgoCD or Flux for declarative config management
2. **Monitoring**: Configure Prometheus ServiceMonitor for TKC metrics
3. **High Availability**: Deploy multiple TKC replicas for redundancy
4. **Disaster Recovery**: Set up GSLB for multi-site load balancing (see `futureplan.md`)

## Support Resources

- TKC Logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=a10-tkc`
- CRD Status: `kubectl get virtualservers,servicegroups,healthmonitors -A`
- Thunder ADC UI: `https://10.98.252.40`
- A10 Documentation: https://documentation.a10networks.com/
