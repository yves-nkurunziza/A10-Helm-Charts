# GitHub Deployment - Quick Start

## Your Public Repository
```
https://github.com/yves-nkurunziza/A10-Helm-Charts.git
Helm Repo: https://yves-nkurunziza.github.io/A10-Helm-Charts
```

## Push to GitHub

On your server (`/home/yves/A10`):

```bash
cd /home/yves/A10

git init
git add .
git commit -m "Production-ready A10 TKC Helm charts"
git remote add origin https://github.com/yves-nkurunziza/A10-Helm-Charts.git
git branch -M main
git push -u origin main
```

## Enable GitHub Pages

1. Go to: https://github.com/yves-nkurunziza/A10-Helm-Charts/settings/pages
2. Source: **gh-pages** branch
3. Click Save

GitHub Actions will automatically create the `gh-pages` branch on first push.

## Using Your Helm Repository

### Add the Repository

```bash
helm repo add a10 https://yves-nkurunziza.github.io/A10-Helm-Charts
helm repo update
```

### Install TKC Operator (Platform Team)

```bash
helm install tkc a10/a10-tkc -n kube-system
```

### Install DNS Load Balancer (DevOps Team)

```bash
helm install dns a10/a10-slb -n production
```

### Verify Installation

```bash
# Check TKC operator
kubectl get pods -n kube-system -l app.kubernetes.io/name=a10-tkc

# Check DNS load balancer resources
kubectl get virtualservers,servicegroups,healthmonitors,virtualports -n production
```

## Updating Charts

```bash
# Make changes to charts
cd /home/yves/A10

# Bump version in Chart.yaml
# a10-tkc/Chart.yaml: version: 1.0.1
# a10-slb/Chart.yaml: version: 1.0.1

# Commit and push
git add .
git commit -m "Update charts to v1.0.1"
git push

# Users update with:
helm repo update
helm upgrade tkc a10/a10-tkc -n kube-system
```

## Check GitHub Actions

After pushing, monitor the release workflow:
https://github.com/yves-nkurunziza/A10-Helm-Charts/actions

Once complete, your charts are available at:
https://yves-nkurunziza.github.io/A10-Helm-Charts/index.yaml
