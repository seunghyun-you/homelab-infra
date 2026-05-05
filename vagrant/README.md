# Vagrant 

## 사용 방법

### 전체 환경 배포

```bash
cd vagrant/

# 전체 VM 생성 및 프로비저닝
vagrant up

# 특정 노드만 생성
vagrant up cilium-ctr cilium-w1 cilium-w2
```

### VM 관리

```bash
# 상태 확인
vagrant status

# SSH 접속
vagrant ssh cilium-ctr

# VM 중지
vagrant halt

# VM 삭제
vagrant destroy -f

# 프로비저닝 재실행
vagrant provision cilium-ctr
```

### kubectl 접근

```bash
# Control Plane에서 직접 사용
vagrant ssh cilium-ctr
kubectl get nodes

# 호스트에서 접근 (kubeconfig 복사 필요)
vagrant ssh cilium-ctr -c "cat ~/.kube/config" > ~/.kube/homelab-config
export KUBECONFIG=~/.kube/homelab-config
kubectl get nodes
```

## Cilium 설정

### Helm Values 주요 설정

```yaml
# kube-proxy 대체
kubeProxyReplacement: true

# Native Routing 모드
routingMode: native
autoDirectNodeRoutes: true
ipv4NativeRoutingCIDR: 172.20.0.0/16

# IPAM 설정
ipam.mode: cluster-pool
ipam.operator.clusterPoolIPv4PodCIDRList: 172.20.0.0/16

# eBPF Masquerade
bpf.masquerade: true

# Hubble (Observability)
hubble.enabled: true
hubble.relay.enabled: true
hubble.ui.enabled: true
hubble.ui.service.type: NodePort
hubble.ui.service.nodePort: 30003

# Prometheus 메트릭
prometheus.enabled: true
operator.prometheus.enabled: true
hubble.metrics.enabled: "{dns,drop,tcp,flow,...}"
```

## 트러블슈팅

### VM 생성 실패 시

```bash
# VirtualBox 로그 확인
cat ~/VirtualBox\ VMs/cilium-ctr/Logs/VBox.log

# Vagrant 디버그 모드
VAGRANT_LOG=debug vagrant up
```

### 네트워크 연결 문제

```bash
# 라우팅 테이블 확인
vagrant ssh cilium-w1 -c "ip route"

# Router 노드 IP Forwarding 확인
vagrant ssh cilium-r -c "cat /proc/sys/net/ipv4/ip_forward"
```

### kubeadm join 실패

```bash
# 토큰 재생성
vagrant ssh cilium-ctr -c "kubeadm token create --print-join-command"

# Worker에서 수동 join
vagrant ssh cilium-w1
kubeadm join 192.168.10.100:6443 --token <token> --discovery-token-unsafe-skip-ca-verification
```

## 버전 업그레이드

Vagrantfile 상단의 변수를 수정하여 버전 변경:

```ruby
K8SV = '1.33.2'           # Kubernetes 버전
K8S_APT_VERSION = '1.33.2-1.1'
CONTAINERDV = '1.7.27-1'  # containerd 버전
CILIUMV = '1.18.0'        # Cilium 버전
```
