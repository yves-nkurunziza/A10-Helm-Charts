# Minimal A10 TKC Installation

This example shows the absolute minimum configuration required to install TKC.

## Prerequisites

- Thunder ADC accessible at 192.168.10.10
- Valid credentials

## Installation

```bash
helm install tkc ../../ \
  --set thunder.host=192.168.10.10 \
  --set thunder.username=admin \
  --set thunder.password=your-password
```

## Values

```yaml
thunder:
  host: "192.168.10.10"
  username: "admin"
  password: "your-password"
```
