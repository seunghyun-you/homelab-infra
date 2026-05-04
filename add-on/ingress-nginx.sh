#!/usr/bin/env bash

set -e
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND"' ERR

INGRESS_NGINX_V="${INGRESS_NGINX_V:-1.10.1}"
INGRESS_NAMESPACE="ingress-nginx"

echo "[TASK] Install Ingress Nginx Controller v${INGRESS_NGINX_V}"

# Install Ingress Nginx Controller
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v${INGRESS_NGINX_V}/deploy/static/provider/cloud/deploy.yaml" \
  >/dev/null 2>&1

# Wait for Ingress Nginx controller to be ready before patching webhook
echo "[TASK] Waiting for Ingress Nginx controller to be ready..."
kubectl rollout status deployment/ingress-nginx-controller -n "${INGRESS_NAMESPACE}" --timeout=300s >/dev/null 2>&1

# Patch webhook to ignore failures
WEBHOOK_COUNT=$(kubectl get validatingwebhookconfiguration ingress-nginx-admission \
  -o jsonpath='{.webhooks}' 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

for i in $(seq 0 $((WEBHOOK_COUNT - 1))); do
  kubectl patch validatingwebhookconfiguration ingress-nginx-admission \
    --type='json' \
    -p="[{\"op\":\"replace\",\"path\":\"/webhooks/${i}/failurePolicy\",\"value\":\"Ignore\"}]" \
    >/dev/null 2>&1 || true
done

echo "[TASK] Ingress Nginx Controller installation complete."
