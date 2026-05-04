#!/usr/bin/env bash

set -e
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND"' ERR

F5_NGINX_V="${F5_NGINX_V:-2.4.3}"
F5_NGINX_NAMESPACE="${F5_NGINX_NAMESPACE:-nginx}"
F5_NGINX_RELEASE="${F5_NGINX_RELEASE:-nginx}"
F5_NGINX_INGRESSCLASS="${F5_NGINX_INGRESSCLASS:-nginx}"
HELM_CHART_DIR="/root/workspace/nginx-ingress"

echo "[TASK] Install F5 NGINX Ingress Controller v${F5_NGINX_V}"

# Pull F5 NGINX Ingress Helm chart
rm -rf "${HELM_CHART_DIR}"
helm pull oci://ghcr.io/nginx/charts/nginx-ingress \
  --untar \
  --untardir /root/workspace \
  --version "${F5_NGINX_V}" \
  >/dev/null 2>&1

# Create namespace
kubectl create namespace "${F5_NGINX_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1

# Install F5 NGINX Ingress Controller
echo "[TASK] Installing F5 NGINX Ingress Controller via Helm..."
helm install "${F5_NGINX_RELEASE}" "${HELM_CHART_DIR}" \
  -n "${F5_NGINX_NAMESPACE}" \
  --set controller.ingressClass.name="${F5_NGINX_INGRESSCLASS}" \
  --set controller.service.externalTrafficPolicy=Cluster \
  --set controller.enableSnippets=true \
  >/dev/null 2>&1

# Wait for F5 NGINX Ingress Controller to be ready
echo "[TASK] Waiting for F5 NGINX Ingress Controller to be ready..."
kubectl rollout status deployment/"${F5_NGINX_RELEASE}-nginx-ingress-controller" \
  -n "${F5_NGINX_NAMESPACE}" --timeout=300s >/dev/null 2>&1

echo "[TASK] F5 NGINX Ingress Controller installation complete. IngressClass: ${F5_NGINX_INGRESSCLASS}"
