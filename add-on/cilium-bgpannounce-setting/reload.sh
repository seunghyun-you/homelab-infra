#!/bin/bash
helm upgrade cilium cilium/cilium --version 1.18.0 --namespace kube-system --reuse-values -f values.yaml
kubectl rollout restart ds cilium -n kube-system
kubectl rollout restart ds cilium-envoy -n kube-system
kubectl rollout restart deploy cilium-operator -n kube-system