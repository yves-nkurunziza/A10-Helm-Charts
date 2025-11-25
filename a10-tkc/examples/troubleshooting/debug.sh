#!/bin/bash
# Debug script for A10 TKC troubleshooting

set -e

NAMESPACE="${1:-default}"
RELEASE="${2:-a10-tkc}"

echo "=== A10 TKC Debug Information ==="
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE"
echo ""

echo "=== Deployment Status ==="
kubectl get deployment -n "$NAMESPACE" -l app.kubernetes.io/name=a10-tkc
echo ""

echo "=== Pod Status ==="
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=a10-tkc
echo ""

echo "=== Pod Logs (last 50 lines) ==="
POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=a10-tkc -o jsonpath='{.items[0].metadata.name}')
if [ -n "$POD" ]; then
  kubectl logs -n "$NAMESPACE" "$POD" --tail=50
else
  echo "No pods found"
fi
echo ""

echo "=== Events ==="
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | grep -i tkc || true
echo ""

echo "=== CRD Resources ==="
kubectl api-resources | grep tkc.a10networks.com || echo "No TKC CRDs found"
echo ""

echo "=== Thunder ADC Connectivity Test ==="
THUNDER_HOST=$(kubectl get secret -n "$NAMESPACE" "${RELEASE}-secret" -o jsonpath='{.data.username}' 2>/dev/null | base64 -d || echo "secret-not-found")
echo "Thunder host from secret: $THUNDER_HOST"
