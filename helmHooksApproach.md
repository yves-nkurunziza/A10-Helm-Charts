# Helm Hooks Approach for A10 SLB Resource Ordering
## (With Acceptable Downtime During Upgrades)

## Overview
Since downtime during upgrades is acceptable, Helm hooks can provide ordering guarantees while keeping resources Helm-managed.

## Implementation Strategy

### Hook Configuration

```yaml
# templates/healthmonitor.yaml
{{- if .Values.healthMonitor.enabled -}}
apiVersion: tkc.a10networks.com/v1
kind: HealthMonitor
metadata:
  name: {{ .Values.healthMonitor.name }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "a10-slb.labels" . | nindent 4 }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-10"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  # ... existing spec
{{- end }}

---

# templates/servicegroup.yaml
{{- if .Values.serviceGroup.enabled -}}
apiVersion: tkc.a10networks.com/v1
kind: ServiceGroup
metadata:
  name: {{ .Values.serviceGroup.name }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "a10-slb.labels" . | nindent 4 }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  # ... existing spec
{{- end }}

---

# templates/virtualserver.yaml
{{- if .Values.virtualServer.enabled -}}
apiVersion: tkc.a10networks.com/v1
kind: VirtualServer
metadata:
  name: {{ .Values.virtualServer.name }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "a10-slb.labels" . | nindent 4 }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  # ... existing spec
{{- end }}

---

# templates/virtualport.yaml
{{- if .Values.virtualPort.enabled -}}
apiVersion: tkc.a10networks.com/v1
kind: VirtualPort
metadata:
  name: {{ .Values.virtualPort.name }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "a10-slb.labels" . | nindent 4 }}
  # NO hook annotations - this is a regular resource
spec:
  # ... existing spec
{{- end }}
```

## Execution Flow

### On Install (`helm install`)
```
1. Pre-install hooks run (in weight order):
   Weight -10: HealthMonitor created
   Weight -5:  ServiceGroup + VirtualServer created (parallel)

2. Helm waits for hooks to complete

3. Regular resources created:
   VirtualPort created (dependencies already exist)

4. Installation complete
```

### On Upgrade (`helm upgrade`)
```
1. Pre-upgrade hooks run:
   Weight -10:
     - Old HealthMonitor DELETED
     - New HealthMonitor created

   Weight -5:
     - Old ServiceGroup DELETED
     - Old VirtualServer DELETED
     - New ServiceGroup created
     - New VirtualServer created

2. Helm waits for hooks to complete

3. Regular resources updated:
   VirtualPort updated/recreated

4. Upgrade complete

⚠️ DOWNTIME WINDOW: From deletion of old resources until new VirtualPort is ready
   (Typically 10-30 seconds)
```

### On Uninstall (`helm uninstall`)
```
1. Regular resources deleted:
   VirtualPort deleted

2. Hook resources REMAIN (hooks don't run on uninstall)
   HealthMonitor still exists
   ServiceGroup still exists
   VirtualServer still exists

⚠️ PROBLEM: Hook resources become orphaned!
```

## The Uninstall Problem

Hook resources with `before-hook-creation` policy **do not get deleted** on `helm uninstall`.

### Solution: Add Cleanup Hooks

```yaml
# templates/cleanup-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "a10-slb.fullname" . }}-cleanup
  namespace: {{ .Release.Namespace }}
  annotations:
    "helm.sh/hook": pre-delete
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": hook-succeeded,hook-failed
spec:
  template:
    spec:
      serviceAccountName: {{ include "a10-slb.fullname" . }}-cleanup
      restartPolicy: Never
      containers:
      - name: cleanup
        image: bitnami/kubectl:latest
        command: ["/bin/sh", "-c"]
        args:
          - |
            set -e
            echo "Cleaning up A10 SLB resources..."

            kubectl delete healthmonitor {{ .Values.healthMonitor.name }} \
              -n {{ .Release.Namespace }} --ignore-not-found=true

            kubectl delete servicegroup {{ .Values.serviceGroup.name }} \
              -n {{ .Release.Namespace }} --ignore-not-found=true

            kubectl delete virtualserver {{ .Values.virtualServer.name }} \
              -n {{ .Release.Namespace }} --ignore-not-found=true

            echo "Cleanup complete"

---
# templates/cleanup-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "a10-slb.fullname" . }}-cleanup
  namespace: {{ .Release.Namespace }}
  annotations:
    "helm.sh/hook": pre-delete
    "helm.sh/hook-weight": "-1"
    "helm.sh/hook-delete-policy": hook-succeeded,hook-failed

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ include "a10-slb.fullname" . }}-cleanup
  namespace: {{ .Release.Namespace }}
  annotations:
    "helm.sh/hook": pre-delete
    "helm.sh/hook-weight": "-1"
    "helm.sh/hook-delete-policy": hook-succeeded,hook-failed
rules:
- apiGroups: ["tkc.a10networks.com"]
  resources: ["healthmonitors", "servicegroups", "virtualservers"]
  verbs: ["delete", "get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ include "a10-slb.fullname" . }}-cleanup
  namespace: {{ .Release.Namespace }}
  annotations:
    "helm.sh/hook": pre-delete
    "helm.sh/hook-weight": "-1"
    "helm.sh/hook-delete-policy": hook-succeeded,hook-failed
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ include "a10-slb.fullname" . }}-cleanup
subjects:
- kind: ServiceAccount
  name: {{ include "a10-slb.fullname" . }}-cleanup
  namespace: {{ .Release.Namespace }}
```

## Complete Lifecycle with Cleanup Hooks

### Install
```bash
helm install web-app a10-slb/ -n production

# Result:
# ✅ HealthMonitor created
# ✅ ServiceGroup created
# ✅ VirtualServer created
# ✅ VirtualPort created
# ✅ All resources managed by Helm
```

### Upgrade
```bash
helm upgrade web-app a10-slb/ \
  --set virtualServer.ipAddress=172.28.3.99

# Result:
# ⏳ Old HealthMonitor deleted → New created
# ⏳ Old ServiceGroup deleted → New created
# ⏳ Old VirtualServer deleted → New created
# ⏳ VirtualPort recreated with new config
# ⚠️ 10-30s downtime (acceptable per requirements)
# ✅ All resources updated and Helm-managed
```

### Uninstall
```bash
helm uninstall web-app

# Result:
# ⏳ Cleanup Job runs
# ✅ HealthMonitor deleted
# ✅ ServiceGroup deleted
# ✅ VirtualServer deleted
# ✅ VirtualPort deleted
# ✅ Cleanup Job deleted
# ✅ Complete cleanup
```

## Pros of This Approach

✅ **Guaranteed ordering** - Hook weights ensure sequence
✅ **No orphaned resources** - Cleanup hooks handle uninstall
✅ **All Helm-managed** - Can view with `helm get manifest`
✅ **Simple to implement** - Just annotations + cleanup job
✅ **No operator changes** - Works with existing TKC operator
✅ **Predictable behavior** - Always creates in same order
✅ **Complete lifecycle** - Install, upgrade, uninstall all handled

## Cons of This Approach

❌ **Downtime on upgrades** - But you said this is acceptable!
❌ **Cleanup job complexity** - Requires RBAC setup
❌ **Hook debugging** - Helm hook failures can be tricky
❌ **Not GitOps-friendly** - ArgoCD doesn't handle hooks well
❌ **Rollback complexity** - Hook resources don't rollback automatically

## What Happens on Rollback?

```bash
# Upgrade with bad config
helm upgrade web-app a10-slb/ --set virtualPort.port=INVALID

# Rollback
helm rollback web-app

# Result:
# ⚠️ Hook resources are NOT rolled back automatically
# ⚠️ Only regular resources (VirtualPort) rollback
# ❌ HealthMonitor, ServiceGroup, VirtualServer stay at "current" version
```

### Solution: Manual Rollback or Re-upgrade

```bash
# Option 1: Re-run upgrade with old values
helm upgrade web-app a10-slb/ -f old-values.yaml

# Option 2: Uninstall and reinstall
helm uninstall web-app
helm install web-app a10-slb/ -f values.yaml
```

## Comparison: Hooks vs. Operator Dependencies

| Aspect | Helm Hooks | Operator Dependencies |
|--------|------------|----------------------|
| **Ordering Guarantee** | ✅ Strong (hook weights) | ✅ Eventual (retry) |
| **Downtime on Upgrade** | ❌ Yes (10-30s) | ✅ None |
| **Implementation Effort** | ✅ Low (annotations) | ❌ High (operator code) |
| **Helm Management** | ✅ Yes (with cleanup hooks) | ✅ Yes |
| **Rollback Support** | ❌ Manual | ✅ Automatic |
| **GitOps Compatible** | ⚠️ Limited | ✅ Full |
| **Operator Changes** | ✅ None needed | ❌ Required |
| **Production Ready** | ⚠️ With caveats | ✅ Industry standard |

## When to Use Helm Hooks Approach

Use this if:
- ✅ Downtime on upgrades is acceptable (your case!)
- ✅ You can't modify the TKC operator
- ✅ You need a solution immediately (< 1 week)
- ✅ You don't use GitOps (ArgoCD/Flux)
- ✅ Upgrades are infrequent
- ✅ You have manual intervention capability

DON'T use this if:
- ❌ You need zero-downtime upgrades
- ❌ You use ArgoCD/Flux for deployments
- ❌ You need automatic rollbacks
- ❌ Upgrades are frequent (daily/weekly)

## Recommended Hook Weights

```
Pre-install/Pre-upgrade Hooks:
-10: HealthMonitor (optional dependency, create first)
-5:  ServiceGroup + VirtualServer (required dependencies, same weight = parallel)
0:   (default - VirtualPort as regular resource)

Pre-delete Hooks:
-1:  Cleanup RBAC (ServiceAccount, Role, RoleBinding)
0:   Cleanup Job (deletes HealthMonitor, ServiceGroup, VirtualServer)
```

## Testing Procedure

### Test 1: Fresh Install
```bash
# Install
helm install test-app a10-slb/ -n test

# Verify order
kubectl get healthmonitors,servicegroups,virtualservers,virtualports -n test

# Check Helm knows about them
helm get manifest test-app

# Check status
kubectl describe virtualport -n test
```

### Test 2: Upgrade
```bash
# Upgrade with config change
helm upgrade test-app a10-slb/ -n test \
  --set virtualServer.ipAddress=172.28.3.99

# Watch recreation
kubectl get virtualservers -n test -w

# Verify new config applied
kubectl get virtualserver -n test -o yaml | grep ipAddress
```

### Test 3: Uninstall
```bash
# Uninstall
helm uninstall test-app -n test

# Verify cleanup
kubectl get healthmonitors,servicegroups,virtualservers,virtualports -n test
# Should return: No resources found

# Check cleanup job ran
kubectl get jobs -n test
# Should show cleanup job completed
```

### Test 4: Failed Hook
```bash
# Install with invalid config (to trigger hook failure)
helm install test-app a10-slb/ -n test \
  --set serviceGroup.healthMonitor=NONEXISTENT

# Check hook status
kubectl get jobs -n test
kubectl logs job/test-app-... -n test

# Cleanup failed install
helm uninstall test-app -n test
```

## Migration from Current Setup

### Step 1: Backup Current Resources
```bash
kubectl get healthmonitor hm-http -o yaml > backup-hm.yaml
kubectl get servicegroup sg-web -o yaml > backup-sg.yaml
kubectl get virtualserver dr-dns-slb -o yaml > backup-vs.yaml
kubectl get virtualport vport-80 -o yaml > backup-vp.yaml
```

### Step 2: Update Chart Templates
Add hook annotations to healthmonitor.yaml, servicegroup.yaml, virtualserver.yaml
Add cleanup-job.yaml and cleanup-rbac.yaml

### Step 3: Test in Non-Production
```bash
helm install test a10-slb/ -n dev -f test-values.yaml
# Verify all works
helm uninstall test -n dev
# Verify cleanup works
```

### Step 4: Upgrade Production
```bash
# This will recreate resources with hooks
helm upgrade web-app a10-slb/ -n production

# Monitor
kubectl get all -n production -w
```

## Troubleshooting

### Hook Stuck in Pending
```bash
# Check hook resources
kubectl get all -n production -l app.kubernetes.io/managed-by=Helm

# Check events
kubectl get events -n production --sort-by='.lastTimestamp'

# Check operator logs
kubectl logs -n kube-system -l app.kubernetes.io/name=a10-tkc
```

### Cleanup Job Fails
```bash
# Check job logs
kubectl logs job/web-app-cleanup -n production

# Check RBAC
kubectl auth can-i delete healthmonitors \
  --as=system:serviceaccount:production:web-app-cleanup \
  -n production

# Manual cleanup if needed
kubectl delete healthmonitor hm-http -n production
kubectl delete servicegroup sg-web -n production
kubectl delete virtualserver dr-dns-slb -n production
```

### Resources Not Deleted on Upgrade
```bash
# Verify hook annotations
helm get manifest web-app | grep -A 5 "hook"

# Check hook-delete-policy
helm get manifest web-app | grep hook-delete-policy

# Manual deletion if needed
kubectl delete healthmonitor hm-http -n production
```

## Final Recommendation

**For your specific case (downtime acceptable):**

✅ **Use Helm Hooks with Cleanup Jobs**

This gives you:
- Guaranteed ordering
- Helm-managed resources
- Complete lifecycle management
- No operator changes needed
- Quick implementation

**Implementation Timeline:**
- Week 1: Add hook annotations, create cleanup job, test in dev
- Week 2: Deploy to production, monitor, document

**Future Consideration:**
If you later need zero-downtime upgrades, you can migrate to operator-based dependencies. The resources won't need changes, just remove the hook annotations.
