#!/bin/bash
# Collect comprehensive logs for A10 TKC troubleshooting

set -e

NAMESPACE="${1:-default}"
RELEASE="${2:-a10-tkc}"
OUTPUT_DIR="${3:-tkc-debug-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$OUTPUT_DIR"

echo "=== Collecting TKC Debug Information ==="
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE"
echo "Output: $OUTPUT_DIR"
echo ""

# Deployment info
echo "Collecting deployment information..."
kubectl get deployment -n "$NAMESPACE" -l app.kubernetes.io/name=a10-tkc -o yaml > "$OUTPUT_DIR/deployment.yaml" 2>&1 || true

# Pod info
echo "Collecting pod information..."
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=a10-tkc -o yaml > "$OUTPUT_DIR/pods.yaml" 2>&1 || true

# Logs
echo "Collecting pod logs..."
for pod in $(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=a10-tkc -o jsonpath='{.items[*].metadata.name}'); do
  echo "  - $pod"
  kubectl logs -n "$NAMESPACE" "$pod" --all-containers > "$OUTPUT_DIR/logs-${pod}.log" 2>&1 || true
  kubectl logs -n "$NAMESPACE" "$pod" --all-containers --previous > "$OUTPUT_DIR/logs-${pod}-previous.log" 2>&1 || true
done

# Events
echo "Collecting events..."
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' > "$OUTPUT_DIR/events.log" 2>&1 || true

# ConfigMaps and Secrets (metadata only, no sensitive data)
echo "Collecting config metadata..."
kubectl get configmap -n "$NAMESPACE" -o yaml > "$OUTPUT_DIR/configmaps.yaml" 2>&1 || true
kubectl get secret -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' > "$OUTPUT_DIR/secrets-list.txt" 2>&1 || true

# RBAC
echo "Collecting RBAC info..."
kubectl get clusterrole,clusterrolebinding -l app.kubernetes.io/name=a10-tkc -o yaml > "$OUTPUT_DIR/rbac.yaml" 2>&1 || true

# CRDs
echo "Collecting CRD information..."
kubectl api-resources | grep tkc.a10networks.com > "$OUTPUT_DIR/crds-available.txt" 2>&1 || true
kubectl get healthmonitors,servicegroups,virtualservers,virtualports --all-namespaces -o yaml > "$OUTPUT_DIR/crd-instances.yaml" 2>&1 || true

# Network
echo "Collecting network policies..."
kubectl get networkpolicy -n "$NAMESPACE" -o yaml > "$OUTPUT_DIR/networkpolicies.yaml" 2>&1 || true

# Resource usage
echo "Collecting resource usage..."
kubectl top pods -n "$NAMESPACE" -l app.kubernetes.io/name=a10-tkc > "$OUTPUT_DIR/resource-usage.txt" 2>&1 || true

# Package everything
echo "Creating archive..."
tar -czf "${OUTPUT_DIR}.tar.gz" "$OUTPUT_DIR"

echo ""
echo "=== Debug information collected ==="
echo "Archive: ${OUTPUT_DIR}.tar.gz"
echo ""
echo "To share with support:"
echo "  1. Review files to ensure no sensitive data"
echo "  2. Upload: ${OUTPUT_DIR}.tar.gz"
