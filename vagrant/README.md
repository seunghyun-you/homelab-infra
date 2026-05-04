# Vagrant 프로비저닝 가이드

Vagrant를 활용한 홈랩 VM 자동 배포 환경입니다.

## 환경 정보

| 항목       | 버전                             |
| ---------- | -------------------------------- |
| Vagrant    | 2.4.x                            |
| VirtualBox | 7.x                              |
| Base Image | bento/ubuntu-24.04 (202502.21.0) |
| Kubernetes | 1.33.2                           |
| Cilium     | 1.18.0                           |
| containerd | 1.7.27                           |

## 파일 구조

```
vagrant/
├── Vagrantfile              # VM 정의 및 프로비저닝 설정
├── kubeadm-config.yaml      # Control Plane 초기화 설정
├── kubeadm-join-config.yaml # Worker 노드 Join 설정
├── init_cfg.sh              # 공통 초기화 (containerd, kubeadm)
├── cilium-ctr.sh            # Control Plane 구성
├── cilium-w.sh              # Worker 노드 Join
├── cilium-r.sh              # Router 노드 구성
├── ceph.sh                  # Ceph 스토리지 노드 구성
├── net-setting-01.sh        # Subnet1 라우팅 설정
├── net-setting-02.sh        # Subnet2 라우팅 설정
└── README.md                # 본 문서
```

## 노드 구성

### Kubernetes 클러스터

| 노드       | 역할             | vCPU | Memory | IP                | SSH Port |
| ---------- | ---------------- | ---- | ------ | ----------------- | -------- |
| cilium-ctr | Control Plane    | 2    | 4GB    | 192.168.10.100    | 60000    |
| cilium-w1  | Worker           | 2    | 4GB    | 192.168.10.101    | 60001    |
| cilium-w2  | Worker           | 2    | 4GB    | 192.168.10.102    | 60002    |
| cilium-w3  | Worker (Subnet2) | 2    | 4GB    | 192.168.20.100    | 60010    |
| cilium-r   | Router           | 1    | 1GB    | .10.200 / .20.200 | 60009    |

### Ceph 스토리지 클러스터

| 노드    | 역할 | vCPU | Memory | OSD Disk | IP             | SSH Port |
| ------- | ---- | ---- | ------ | -------- | -------------- | -------- |
| ceph-01 | OSD  | 2    | 4GB    | 100GB    | 192.168.10.201 | 50001    |
| ceph-02 | OSD  | 2    | 4GB    | 100GB    | 192.168.10.202 | 50002    |
| ceph-03 | OSD  | 2    | 4GB    | 100GB    | 192.168.10.203 | 50003    |

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

## 프로비저닝 상세

### 1. init_cfg.sh (공통)

모든 K8s 노드에서 실행되는 초기화 스크립트:

```
[TASK 1] 프로파일 설정 (timezone, alias)
[TASK 2] AppArmor/UFW 비활성화
[TASK 3] Swap 비활성화
[TASK 4] 패키지 설치 (apt-transport-https, curl, gpg)
[TASK 5] Kubernetes 컴포넌트 설치 (kubeadm, kubelet, kubectl, containerd)
[TASK 6] 유틸리티 설치 (helm, net-tools, tcpdump, jq, etc.)
```

### 2. cilium-ctr.sh (Control Plane)

```
[TASK 1]  kubeadm init (kube-proxy 스킵)
[TASK 2]  kubeconfig 설정
[TASK 3]  kubectl 자동완성
[TASK 4]  alias 설정 (k=kubectl)
[TASK 5]  kubectx/kubens 설치
[TASK 6]  kube-ps1 설치
[TASK 7]  Cilium CNI 설치 (Helm)
[TASK 8]  Cilium/Hubble CLI 설치
[TASK 9]  /etc/hosts DNS 설정
[TASK 10] Prometheus & Grafana 배포
[TASK 11] local-path-provisioner 설치
[TASK 13] metrics-server 설치
[TASK 14] k9s 설치
```

### 3. cilium-w.sh (Worker)

```
[TASK 1] kubeadm join 실행
```

### 4. cilium-r.sh (Router)

```
[TASK 0] eth2 네트워크 인터페이스 설정
[TASK 1] 프로파일 설정
[TASK 2] AppArmor/UFW 비활성화
[TASK 3] IP Forwarding 활성화
[TASK 4] Dummy 인터페이스 생성 (loop1, loop2)
[TASK 5] 네트워크 유틸리티 설치
[TASK 6] Apache 웹서버 설치 (테스트용)
```

### 5. ceph.sh (Ceph Node)

```
[TASK 1] 프로파일 설정
[TASK 2] AppArmor/UFW 비활성화
[TASK 3] /etc/hosts DNS 설정
[TASK 4] chrony, docker 설치
[TASK 5] cephadm 설치 (reef 버전)
[TASK 6] SSH 설정 (root 로그인 허용)
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

## 서비스 접근

배포 완료 후 접근 가능한 서비스:

| 서비스     | URL                         | 비고            |
| ---------- | --------------------------- | --------------- |
| Prometheus | http://192.168.10.100:30001 | 메트릭 조회     |
| Grafana    | http://192.168.10.100:30002 | 대시보드        |
| Hubble UI  | http://192.168.10.100:30003 | 네트워크 플로우 |

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
