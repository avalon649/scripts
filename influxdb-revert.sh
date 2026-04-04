#!/usr/bin/env bash
# revert.sh
# Removes influxdb2 from ArgoCD management and restores plain Helm control.
# Safe to run — does NOT delete any resources or GitHub files.

set -euo pipefail

KUBECONFIG="${KUBECONFIG:-/home/avalon/.kube/k3s-prod/config}"
export KUBECONFIG

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
confirm() {
  read -rp "$(echo -e "${YELLOW}[CONFIRM]${NC} $* (y/N): ")" ans
  [[ "${ans,,}" == "y" ]]
}

echo ""
echo "=================================================="
echo "  Revert influxdb2 ArgoCD onboarding"
echo "=================================================="
echo ""
warn "This will:"
echo "  1. Remove the ArgoCD Application 'influxdb2' (resources kept)"
echo "  2. All monitoring resources remain untouched"
echo "  3. GitHub repo is not modified"
echo ""

confirm "Proceed?" || { echo "Aborted."; exit 0; }

# ── Step 1: Delete ArgoCD Application without cascading ──────────────────────
info "Step 1/1 — Removing ArgoCD Application (non-cascade, resources kept)..."

if kubectl get application influxdb2 -n argocd &>/dev/null; then
  kubectl patch application influxdb2 -n argocd \
    --type merge \
    -p '{"metadata":{"finalizers":[]}}' 2>/dev/null || true

  kubectl delete application influxdb2 -n argocd
  info "ArgoCD Application deleted."
else
  warn "ArgoCD Application 'influxdb2' not found — already removed."
fi

# ── Verify Helm still owns the release ───────────────────────────────────────
echo ""
info "Verifying Helm release is still intact..."
helm list -n monitoring | grep infuxdb2 \
  && info "Helm release OK — influxdb2 is back under plain Helm control." \
  || warn "Helm release not found — check with: helm list -n monitoring"

echo ""
info "Monitoring pod status:"
kubectl get pods -n monitoring

echo ""
echo -e "${GREEN}Done.${NC}"
echo "To make future changes use Helm directly:"
echo "  helm upgrade infuxdb2 influxdata/influxdb2 \\"
echo "    -n monitoring -f ~/path/to/values.yaml"
