# Production A10 TKC Installation

Production-ready configuration with all features enabled.

## Features

- Network policies enabled
- PodDisruptionBudget configured
- Resource limits tuned for production
- Leader election enabled
- Pre-install validation enabled

## Installation

```bash
helm install tkc ../../ -f values.yaml
```

## Values

See `values.yaml` for full configuration.
