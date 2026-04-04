#!/usr/bin/env bash
# revert-prometheus-stack-argocd.sh
# Removes prometheus-stack from ArgoCD management and restores plain Helm control.
# Safe to run — does NOT delete any monitoring resources or GitHub files.

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
echo "  Revert prometheus-stack ArgoCD onboarding"
echo "=================================================="
echo ""
warn "This will:"
echo "  1. Remove the ArgoCD Application 'prometheus-stack' (resources kept)"
echo "  2. Remove the ArgoCD managed-by annotation from the monitoring namespace"
echo "  All monitoring resources remain untouched. GitHub repo is not modified."
echo ""

confirm "Proceed?" || { echo "Aborted."; exit 0; }

# ── Step 1: Delete ArgoCD Application without cascading ──────────────────────
info "Step 1/2 — Removing ArgoCD Application (non-cascade, resources kept)..."

if kubectl get application prometheus-stack -n argocd &>/dev/null; then
  # Strip the ArgoCD finalizer so deletion doesn't cascade to k8s resources
  kubectl patch application prometheus-stack -n argocd \
    --type merge \
    -p '{"metadata":{"finalizers":[]}}' 2>/dev/null || true

  kubectl delete application prometheus-stack -n argocd
  info "ArgoCD Application deleted."
else
  warn "ArgoCD Application 'prometheus-stack' not found — already removed."
fi

# ── Step 2: Remove namespace annotation ──────────────────────────────────────
info "Step 2/2 — Removing argocd managed-by annotation from monitoring namespace..."

kubectl annotate namespace monitoring \
  argocd.argoproj.io/managed-by- \
  --overwrite 2>/dev/null || true

info "Namespace annotation removed."

# ── Verify Helm still owns the release ───────────────────────────────────────
echo ""
info "Verifying Helm release is still intact..."
helm list -n monitoring | grep prometheus-stack \
  && info "Helm release OK — prometheus-stack is back under plain Helm control." \
  || warn "Helm release not found — check with: helm list -n monitoring"

echo ""
info "Monitoring pod status:"
kubectl get pods -n monitoring

echo ""
echo -e "${GREEN}Done.${NC}"
echo "To make future changes use Helm directly:"
echo "  helm upgrade prometheus-stack prometheus-community/kube-prometheus-stack \\"
echo "    -n monitoring -f ~/path/to/values.yaml"
