# Helm Hooks Implementation - Usage Guide

## Overview

The A10 SLB Helm chart now uses Helm hooks to ensure proper resource creation order:

```
Order of Execution:
1. Pre-install/Pre-upgrade Hooks (Weight -10): HealthMonitor
2. Pre-install/Pre-upgrade Hooks (Weight -5):  ServiceGroup, VirtualServer (parallel)
3. Regular Resources:                          VirtualPort
4. Pre-delete Hooks:                           Cleanup Job + RBAC
```

## What Changed

### Modified Templates
- ✅ `templates/healthmonitor.yaml` - Added hook annotations (weight: -10)
- ✅ `templates/servicegroup.yaml` - Added hook annotations (weight: -5)
- ✅ `templates/virtualserver.yaml` - Added hook annotations (weight: -5)
- ✅ `templates/virtualport.yaml` - **NO CHANGES** (regular resource)

### New Templates
- ✅ `templates/cleanup-job.yaml` - Job to delete hook resources on uninstall
- ✅ `templates/cleanup-rbac.yaml` - ServiceAccount, Role, RoleBinding for cleanup

## Hook Annotations Explained

### HealthMonitor (Weight -10)
```yaml
annotations:
  "helm.sh/hook": pre-install,pre-upgrade
  "helm.sh/hook-weight": "-10"
  "helm.sh/hook-delete-policy": before-hook-creation
```

- **Hook Type**: Runs before install and upgrade
- **Weight**: -10 (runs first)
- **Delete Policy**: Deleted and recreated on each upgrade

### ServiceGroup & VirtualServer (Weight -5)
```yaml
annotations:
  "helm.sh/hook": pre-install,pre-upgrade
  "helm.sh/hook-weight": "-5"
  "helm.sh/hook-delete-policy": before-hook-creation
```

- **Hook Type**: Runs before install and upgrade
- **Weight**: -5 (runs after HealthMonitor, in parallel with each other)
- **Delete Policy**: Deleted and recreated on each upgrade

### Cleanup Resources (Pre-delete Hook)
```yaml
annotations:
  "helm.sh/hook": pre-delete
  "helm.sh/hook-weight": "-1" (RBAC) or "0" (Job)
  "helm.sh/hook-delete-policy": hook-succeeded,hook-failed
```

- **Hook Type**: Runs before uninstall
- **Delete Policy**: Cleanup resources themselves are deleted after running

## Installation

### Fresh Install

```bash
# Navigate to chart directory
cd /Users/yvesnkurunziza/A10/a10-slb

# Install the chart
helm install web-app . -n production

# Expected output:
NAME: web-app
LAST DEPLOYED: [timestamp]
NAMESPACE: production
STATUS: deployed
REVISION: 1
```

**What happens:**
1. Helm executes pre-install hooks (HealthMonitor, ServiceGroup, VirtualServer)
2. Helm waits for hooks to complete
3. Helm creates regular resources (VirtualPort)
4. Installation complete

**Verify installation:**
```bash
# Check all resources
kubectl get healthmonitors,servicegroups,virtualservers,virtualports -n production

# Expected output:
NAME                                          AGE
healthmonitor.tkc.a10networks.com/hm-http     30s

NAME                                        AGE
servicegroup.tkc.a10networks.com/sg-web     25s

NAME                                              AGE
virtualserver.tkc.a10networks.com/dr-dns-slb      25s

NAME                                        AGE
virtualport.tkc.a10networks.com/vport-80    20s
```

**Check which resources Helm knows about:**
```bash
helm get manifest web-app -n production

# NOTE: Hook resources (HealthMonitor, ServiceGroup, VirtualServer) will
# NOT appear here because they're hooks, not regular resources!
# Only VirtualPort and cleanup resources will show.
```

### Upgrade

```bash
# Upgrade with new VIP address
helm upgrade web-app . -n production \
  --set virtualServer.ipAddress=172.28.3.99

# Expected output:
Release "web-app" has been upgraded. Happy Helming!
NAME: web-app
LAST DEPLOYED: [timestamp]
NAMESPACE: production
STATUS: deployed
REVISION: 2
```

**What happens:**
1. **Old HealthMonitor deleted** (⚠️ downtime starts)
2. **New HealthMonitor created**
3. **Old ServiceGroup deleted**
4. **Old VirtualServer deleted**
5. **New ServiceGroup created**
6. **New VirtualServer created**
7. **VirtualPort updated/recreated**
8. ⚠️ **Downtime: ~10-30 seconds** (but you said this is acceptable!)

**Watch the upgrade in real-time:**
```bash
# In one terminal, watch resources
kubectl get healthmonitors,servicegroups,virtualservers,virtualports -n production -w

# In another terminal, run upgrade
helm upgrade web-app . -n production --set virtualServer.ipAddress=172.28.3.99
```

### Uninstall

```bash
# Uninstall the release
helm uninstall web-app -n production

# Expected output:
release "web-app" uninstalled
```

**What happens:**
1. **Pre-delete hooks execute:**
   - Weight -1: RBAC resources created (ServiceAccount, Role, RoleBinding)
   - Weight 0: Cleanup Job runs
2. **Cleanup Job deletes:**
   - HealthMonitor
   - ServiceGroup
   - VirtualServer
3. **Regular resources deleted:**
   - VirtualPort
4. **Cleanup resources deleted:**
   - Job, ServiceAccount, Role, RoleBinding

**Verify complete cleanup:**
```bash
# Check if all resources are gone
kubectl get healthmonitors,servicegroups,virtualservers,virtualports -n production

# Expected output:
No resources found in production namespace.
```

**Check cleanup job logs (if debugging):**
```bash
# List jobs
kubectl get jobs -n production

# View cleanup job logs (before it's deleted)
kubectl logs job/web-app-a10-slb-cleanup -n production
```

## Testing Procedure

### Test 1: Fresh Install

```bash
# Clean slate
kubectl delete namespace test-slb
kubectl create namespace test-slb

# Install
helm install test1 . -n test-slb

# Verify all resources created
kubectl get healthmonitors,servicegroups,virtualservers,virtualports -n test-slb

# Check resource ages (should be in order)
kubectl get healthmonitors,servicegroups,virtualservers,virtualports -n test-slb \
  --sort-by=.metadata.creationTimestamp

# Expected order:
# 1. HealthMonitor (oldest)
# 2. ServiceGroup, VirtualServer (same age or close)
# 3. VirtualPort (newest)
```

### Test 2: Upgrade with Config Change

```bash
# Upgrade VirtualServer IP
helm upgrade test1 . -n test-slb \
  --set virtualServer.ipAddress=172.28.3.100

# Verify new IP applied
kubectl get virtualserver dr-dns-slb -n test-slb -o yaml | grep ip-address

# Expected output:
  ip-address: "172.28.3.100"
```

### Test 3: Uninstall and Cleanup

```bash
# Uninstall
helm uninstall test1 -n test-slb

# Immediately check cleanup job
kubectl get jobs -n test-slb

# Expected: You might see the cleanup job briefly
# NAME                      COMPLETIONS   DURATION   AGE
# test1-a10-slb-cleanup     0/1           5s         5s

# Wait a few seconds, then verify all resources deleted
sleep 10
kubectl get healthmonitors,servicegroups,virtualservers,virtualports -n test-slb

# Expected:
# No resources found in test-slb namespace.
```

### Test 4: Verify Hook Resources Not in Manifest

```bash
# Install
helm install test2 . -n test-slb

# Get Helm manifest
helm get manifest test2 -n test-slb

# Verify:
# ✅ VirtualPort should be present
# ✅ Cleanup Job should be present
# ❌ HealthMonitor should NOT be present (it's a hook)
# ❌ ServiceGroup should NOT be present (it's a hook)
# ❌ VirtualServer should NOT be present (it's a hook)
```

### Test 5: Rollback Behavior

```bash
# Install with initial config
helm install test3 . -n test-slb \
  --set virtualServer.ipAddress=172.28.3.20

# Upgrade with new config
helm upgrade test3 . -n test-slb \
  --set virtualServer.ipAddress=172.28.3.99

# Try to rollback
helm rollback test3 -n test-slb

# ⚠️ WARNING: Hook resources will NOT rollback automatically!
# You'll need to manually re-upgrade with old values:
helm upgrade test3 . -n test-slb \
  --set virtualServer.ipAddress=172.28.3.20
```

## Troubleshooting

### Problem: Hook Stuck, Install Fails

**Symptom:**
```bash
helm install web-app . -n production
# Hangs or fails with timeout
```

**Diagnosis:**
```bash
# Check hook resources
kubectl get healthmonitors,servicegroups,virtualservers -n production

# Check TKC operator logs
kubectl logs -n kube-system -l app.kubernetes.io/name=a10-tkc --tail=100

# Check events
kubectl get events -n production --sort-by='.lastTimestamp' | tail -20
```

**Solution:**
```bash
# If hook failed, delete manually
kubectl delete healthmonitor hm-http -n production
kubectl delete servicegroup sg-web -n production
kubectl delete virtualserver dr-dns-slb -n production

# Retry install
helm install web-app . -n production
```

### Problem: Resources Not Deleted on Uninstall

**Symptom:**
```bash
helm uninstall web-app -n production
# Resources still exist
kubectl get healthmonitors,servicegroups,virtualservers -n production
# Still shows resources
```

**Diagnosis:**
```bash
# Check cleanup job status
kubectl get jobs -n production

# Check cleanup job logs
kubectl logs job/web-app-a10-slb-cleanup -n production

# Check RBAC permissions
kubectl auth can-i delete healthmonitors \
  --as=system:serviceaccount:production:web-app-a10-slb-cleanup \
  -n production
```

**Solution:**
```bash
# Manual cleanup if job failed
kubectl delete healthmonitor hm-http -n production
kubectl delete servicegroup sg-web -n production
kubectl delete virtualserver dr-dns-slb -n production
kubectl delete job web-app-a10-slb-cleanup -n production
```

### Problem: Hook Resources Don't Update on Upgrade

**Symptom:**
```bash
helm upgrade web-app . -n production \
  --set virtualServer.ipAddress=172.28.3.99

# IP doesn't change
kubectl get virtualserver dr-dns-slb -n production -o yaml | grep ip-address
# Still shows old IP
```

**Diagnosis:**
```bash
# Check hook annotations
helm get manifest web-app -n production | grep -A 5 "hook"

# Verify hook-delete-policy is set
kubectl get virtualserver dr-dns-slb -n production -o yaml | grep -A 3 "annotations"
```

**Solution:**
The hook-delete-policy should be "before-hook-creation" which means:
- On upgrade, old resource is deleted
- Then new resource is created

If this isn't happening, manually delete and re-upgrade:
```bash
kubectl delete virtualserver dr-dns-slb -n production
helm upgrade web-app . -n production \
  --set virtualServer.ipAddress=172.28.3.99
```

## Downtime Expectations

### During Install
- ✅ **No downtime** (resources don't exist yet)

### During Upgrade
- ⚠️ **10-30 seconds downtime** due to resource deletion and recreation
- Downtime window: From deletion of old VirtualServer until new VirtualPort is ready

**Downtime breakdown:**
```
T+0s:  Old HealthMonitor deleted
T+1s:  New HealthMonitor created on Thunder ADC
T+2s:  Old ServiceGroup deleted (⚠️ traffic loss begins)
T+3s:  Old VirtualServer deleted
T+4s:  New ServiceGroup created
T+5s:  New VirtualServer created
T+10s: VirtualPort reconciled with new config
T+15s: ✅ Traffic restored
```

### During Uninstall
- ⚠️ **Immediate downtime** (VirtualPort deleted first, then dependencies)

## Best Practices

### 1. Use Namespaces for Isolation
```bash
# Production
helm install prod-app . -n production

# Staging
helm install stage-app . -n staging

# Each gets isolated resources
```

### 2. Use Values Files for Different Environments
```bash
# prod-values.yaml
virtualServer:
  ipAddress: "172.28.3.20"
serviceGroup:
  serviceRef:
    name: "prod-web-service"

# Install with values file
helm install prod-app . -n production -f prod-values.yaml
```

### 3. Plan Maintenance Windows for Upgrades
Since upgrades cause 10-30s downtime, schedule during maintenance windows:

```bash
# Schedule maintenance window
# Then upgrade
helm upgrade web-app . -n production -f new-values.yaml
```

### 4. Monitor Cleanup Job on Uninstall
```bash
# Uninstall
helm uninstall web-app -n production

# Monitor cleanup
kubectl get jobs -n production -w

# Check logs if needed
kubectl logs job/web-app-a10-slb-cleanup -n production -f
```

### 5. Keep Values in Version Control
```bash
# values/production.yaml
# values/staging.yaml
# values/dev.yaml

# Install from git repo
helm install prod-app . -f values/production.yaml
```

## Comparison with Previous (No Hooks)

| Aspect | Without Hooks | With Hooks |
|--------|---------------|------------|
| **Install Order** | ❌ Random | ✅ Guaranteed (HealthMonitor → ServiceGroup/VirtualServer → VirtualPort) |
| **Upgrade Order** | ❌ Random | ✅ Guaranteed |
| **Downtime on Upgrade** | ⚠️ Unpredictable | ⚠️ Predictable (10-30s) |
| **Cleanup on Uninstall** | ⚠️ Manual | ✅ Automatic |
| **Helm Management** | ✅ All resources | ⚠️ VirtualPort only (hooks not in manifest) |
| **Rollback** | ✅ Works | ⚠️ Manual re-upgrade needed |

## Migration from Non-Hooks Version

If you have existing installations without hooks:

```bash
# Existing install (no hooks)
# When you upgrade to hooks version, resources will be recreated

# Upgrade to hooks version
helm upgrade web-app . -n production

# What happens:
# 1. Old resources remain (not deleted)
# 2. New hook resources created (different lifecycle)
# 3. You may have duplicates!

# Recommended: Clean install
helm uninstall web-app -n production
# Manually delete old resources
kubectl delete healthmonitor hm-http -n production
kubectl delete servicegroup sg-web -n production
kubectl delete virtualserver dr-dns-slb -n production
kubectl delete virtualport vport-80 -n production
# Fresh install with hooks
helm install web-app . -n production
```

## Next Steps

1. **Test in Development:**
   ```bash
   helm install test-app . -n dev
   helm upgrade test-app . -n dev --set virtualServer.ipAddress=NEW_IP
   helm uninstall test-app -n dev
   ```

2. **Validate in Staging:**
   ```bash
   helm install stage-app . -n staging -f values/staging.yaml
   # Monitor behavior
   helm upgrade stage-app . -n staging -f values/staging-v2.yaml
   ```

3. **Deploy to Production:**
   ```bash
   # During maintenance window
   helm install prod-app . -n production -f values/production.yaml
   ```

4. **Monitor and Document:**
   - Monitor TKC operator logs during install/upgrade
   - Document actual downtime observed
   - Create runbooks for troubleshooting

## Future Improvements

If you later need zero-downtime upgrades, you can migrate to **operator-based dependencies** approach (see `operatorDependenciesApproach.md`). The migration path:

1. Deploy updated TKC operator with dependency logic
2. Remove hook annotations from templates
3. Upgrade Helm chart (operator takes over ordering)
4. Resources updated in-place with zero downtime

## Support

For issues or questions:
- Check TKC operator logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=a10-tkc`
- Review this guide's troubleshooting section
- Examine cleanup job logs: `kubectl logs job/RELEASE-a10-slb-cleanup -n NAMESPACE`
