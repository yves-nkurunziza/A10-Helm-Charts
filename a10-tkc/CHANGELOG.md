# CHANGELOG

All notable changes to this project will be documented in this file.

## [1.0.0] - 2024-11-24

### Added
- Initial production-ready release
- Architecture split: operator vs config charts
- Security hardening (non-root, read-only FS, seccomp)
- RBAC scoped to specific secrets
- Health probes (liveness/readiness)
- PodDisruptionBudget
- NetworkPolicy for egress control
- Leader election support
- Rolling update strategy (maxUnavailable: 0)
- Graceful shutdown with preStop hook
- Values validation schema
- Helm tests for connectivity
- Pre-install validation hook
- ServiceMonitor for Prometheus Operator
- Comprehensive examples (minimal, production)
- Troubleshooting scripts
- Complete documentation

### Fixed
- Double base64 encoding in secrets (now uses stringData)
- Secret rotation (checksum annotation triggers pod restart)
- Namespace references (use .Release.Namespace)

### Known Limitations
- Single Thunder ADC support only (no HA pair)
- Credentials in values.yaml (external secret management recommended)
- No webhook configuration (cert-manager integration needed)
- Assumes TKC controller implements:
  - Leader election
  - Health endpoints (/healthz, /ready)
  - Metrics endpoint (/metrics)
  - Status subresource updates

### Security Notes
- Runs as UID 65534 (nobody)
- No privileged containers
- All capabilities dropped
- Read-only root filesystem
- Seccomp profile enabled
- RBAC limited to specific secret name

## Upgrade Notes

N/A - Initial release
