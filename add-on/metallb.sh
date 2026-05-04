#!/usr/bin/env bash

set -e
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND"' ERR

METALLBV="${METALLBV:-0.14.9}"
METALLB_IP_RANGE="${METALLB_IP_RANGE:-192.168.20.200-192.168.20.210}"
METALLB_NAMESPACE="metallb-system"

echo "[TASK] Install MetalLB v${METALLBV}"

# Enable strictARP for kube-proxy IPVS mode
kubectl patch configmap kube-proxy -n kube-system --patch \
  '{"data":{"config.conf":"apiVersion: kubeproxy.config.k8s.io/v1alpha1\nkind: KubeProxyConfiguration\nmode: \"ipvs\"\nipvs:\n  strictARP: true"}}' \
  >/dev/null 2>&1

# Install MetalLB
kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/v${METALLBV}/config/manifests/metallb-native.yaml" \
  >/dev/null 2>&1

# Wait for MetalLB controller to be ready before patching webhook
echo "[TASK] Waiting for MetalLB controller to be ready..."
kubectl rollout status deployment/controller -n "${METALLB_NAMESPACE}" --timeout=120s >/dev/null 2>&1

# Patch MetalLB webhook to ignore failures
WEBHOOK_COUNT=$(kubectl get validatingwebhookconfiguration metallb-webhook-configuration \
  -o jsonpath='{.webhooks}' 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

for i in $(seq 0 $((WEBHOOK_COUNT - 1))); do
  kubectl patch validatingwebhookconfiguration metallb-webhook-configuration \
    --type='json' \
    -p="[{\"op\":\"replace\",\"path\":\"/webhooks/${i}/failurePolicy\",\"value\":\"Ignore\"}]" \
    >/dev/null 2>&1 || true
done

# Wait for CRDs to be established before applying pool config
echo "[TASK] Waiting for MetalLB CRDs to be established..."
kubectl wait --for=condition=established crd/ipaddresspools.metallb.io --timeout=60s >/dev/null 2>&1
kubectl wait --for=condition=established crd/l2advertisements.metallb.io --timeout=60s >/dev/null 2>&1

# Create IPAddressPool and L2Advertisement
kubectl apply -f - >/dev/null 2>&1 <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: metal-ip-pool
  namespace: ${METALLB_NAMESPACE}
spec:
  addresses:
    - ${METALLB_IP_RANGE}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: metal-adv
  namespace: ${METALLB_NAMESPACE}
spec:
  ipAddressPools:
    - metal-ip-pool
EOF

echo "[TASK] MetalLB installation complete. IP Range: ${METALLB_IP_RANGE}"
