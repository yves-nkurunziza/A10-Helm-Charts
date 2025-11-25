# GitHub Workflow

## Setup Steps

### 1. Create GitHub Repository

```bash
cd /home/yves/A10

# Initialize git
git init
git add .
git commit -m "Initial commit: A10 TKC Helm charts"

# Create repo on GitHub, then:
git remote add origin https://github.com/yvesnkurunziza/a10-charts.git
git branch -M main
git push -u origin main
```

### 2. Enable GitHub Pages

1. Go to repository **Settings** → **Pages**
2. Source: **gh-pages** branch
3. Save

The workflow will automatically create this branch and publish charts.

### 3. First Release

After pushing to main, GitHub Actions will:
1. Package both charts
2. Create `gh-pages` branch
3. Publish `index.yaml` to GitHub Pages
4. Your chart repo will be live at: `https://yvesnkurunziza.github.io/a10-charts`

### 4. Install Charts from Repo

**Platform Team:**
```bash
# Add Helm repository
helm repo add a10 https://yvesnkurunziza.github.io/a10-charts
helm repo update

# Install TKC operator
helm install tkc a10/a10-tkc -n kube-system

# Check what was installed
helm list -n kube-system
```

**DevOps Teams:**
```bash
# Install application config
helm install web-app a10/a10-slb -n production \
  --set virtualServer.ipAddress=10.98.252.100
```

## Updating Charts

### Bump Version

Edit `Chart.yaml`:
```yaml
version: 1.0.1  # Increment this
```

### Push Changes

```bash
git add .
git commit -m "Bump chart version to 1.0.1"
git push
```

GitHub Actions automatically:
- Packages new version
- Updates Helm repo index
- Makes it available via `helm repo update`

## Local Development Testing

```bash
# On your server at /home/yves/A10
helm install tkc ./a10-tkc -n kube-system --dry-run --debug

# Actually install from local
helm install tkc ./a10-tkc -n kube-system
```

## Workflow Benefits

✅ **Version Control**: All changes tracked in Git  
✅ **Automated Releases**: Push = new chart version  
✅ **Team Distribution**: Everyone uses `helm repo add`  
✅ **Rollback**: `helm rollback` works with versioned charts  
✅ **Professional**: Standard Helm chart distribution method
