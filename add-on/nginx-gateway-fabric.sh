#!/usr/bin/env bash

set -e
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND"' ERR

GATEWAY_API_V="${GATEWAY_API_V:-1.4.1}"
NGF_V="${NGF_V:-}"
NGF_NAMESPACE="${NGF_NAMESPACE:-nginx-gateway}"
NGF_RELEASE="${NGF_RELEASE:-ngf}"
HELM_CHART_DIR="/root/workspace/nginx-gateway-fabric"

echo "[TASK] Install Gateway API v${GATEWAY_API_V}"

# Install Gateway API CRDs (Standard Channel)
kubectl apply --server-side \
  -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/v${GATEWAY_API_V}/standard-install.yaml" \
  >/dev/null 2>&1

# Wait for Gateway API CRDs to be established
echo "[TASK] Waiting for Gateway API CRDs to be established..."
kubectl wait --for=condition=established \
  crd/gateways.gateway.networking.k8s.io \
  crd/httproutes.gateway.networking.k8s.io \
  crd/gatewayclasses.gateway.networking.k8s.io \
  --timeout=60s >/dev/null 2>&1

echo "[TASK] Install NGINX Gateway Fabric"

# Pull NGINX Gateway Fabric Helm chart
rm -rf "${HELM_CHART_DIR}"
helm pull oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --untar \
  --untardir /root/workspace \
  ${NGF_V:+--version "${NGF_V}"} \
  >/dev/null 2>&1

# Install NGINX Gateway Fabric
helm install "${NGF_RELEASE}" "${HELM_CHART_DIR}" \
  --create-namespace \
  -n "${NGF_NAMESPACE}" \
  >/dev/null 2>&1

# Wait for NGINX Gateway Fabric to be ready
echo "[TASK] Waiting for NGINX Gateway Fabric to be ready..."
kubectl rollout status deployment/"${NGF_RELEASE}-nginx-gateway-fabric" \
  -n "${NGF_NAMESPACE}" --timeout=300s >/dev/null 2>&1

echo "[TASK] NGINX Gateway Fabric installation complete."
