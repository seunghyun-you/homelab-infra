# 01. Hybrid-Cloud HomeLab

단일 Mini-PC에 Vagrant + VirtualBox로 K8s 클러스터를 구성하고, Oracle Cloud(OCI) Free Tier VM을 Reverse Proxy로 연동한 하이브리드 홈랩 환경입니다.

## Directory Structure

```
01-homelab/
├── vagrant/     # VM 프로비저닝 (Vagrantfile + 스크립트)
├── openvpn/     # OpenVPN 서버/클라이언트 설정 파일
├── script/      # SSL/TLS 인증서 갱신 자동화
└── add-on/      # 선택 설치 애드온 (Ingress, MetalLB 등)
```

## 환경 정보

| 항목       | 버전                             |
| ---------- | -------------------------------- |
| Vagrant    | 2.4.x                            |
| VirtualBox | 7.x                              |
| Base Image | bento/ubuntu-24.04 (202502.21.0) |
| Kubernetes | 1.33.2                           |
| Cilium     | 1.18.0                           |
| containerd | 1.7.27                           |


## 1. Vagrant

### 파일 구조

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

### VM 구성

#### Kubernetes 클러스터

| 노드       | 역할             | vCPU | Memory | IP                | SSH Port |
| ---------- | ---------------- | ---- | ------ | ----------------- | -------- |
| cilium-ctr | Control Plane    | 2    | 4GB    | 192.168.10.100    | 60000    |
| cilium-w1  | Worker           | 2    | 4GB    | 192.168.10.101    | 60001    |
| cilium-w2  | Worker           | 2    | 4GB    | 192.168.10.102    | 60002    |
| cilium-w3  | Worker (Subnet2) | 2    | 4GB    | 192.168.20.100    | 60010    |
| cilium-r   | Router           | 1    | 1GB    | .10.200 / .20.200 | 60009    |

#### Ceph 스토리지 클러스터

| 노드    | 역할 | vCPU | Memory | OSD Disk | IP             | SSH Port |
| ------- | ---- | ---- | ------ | -------- | -------------- | -------- |
| ceph-01 | OSD  | 2    | 4GB    | 100GB    | 192.168.10.201 | 50001    |
| ceph-02 | OSD  | 2    | 4GB    | 100GB    | 192.168.10.202 | 50002    |
| ceph-03 | OSD  | 2    | 4GB    | 100GB    | 192.168.10.203 | 50003    |


### 네트워크 구성

| 구분         | CIDR               | 용도                                    |
| ------------ | ------------------ | --------------------------------------- |
| Subnet1      | 192.168.10.0/24    | K8s Primary (ctr, w1, w2, router, ceph) |
| Subnet2      | 192.168.20.0/24    | K8s Secondary (w3, router)              |
| Pod CIDR     | 172.20.0.0/16      | Cilium Pod Network                      |
| Service CIDR | 10.96.0.0/16       | K8s Service                             |
| LB Pool      | 192.168.10.240-255 | Cilium L2 Announcement                  |
| Ceph Public  | 192.168.50.0/24    | 클라이언트 → OSD                        |
| Ceph Cluster | 192.168.60.0/24    | OSD 간 복제/복구                        |

### Provisioning

#### 1. init_cfg.sh (공통)

모든 K8s 노드에서 실행되는 초기화 스크립트:

```
[TASK 1] 프로파일 설정 (timezone, alias)
[TASK 2] AppArmor/UFW 비활성화
[TASK 3] Swap 비활성화
[TASK 4] 패키지 설치 (apt-transport-https, curl, gpg)
[TASK 5] Kubernetes 컴포넌트 설치 (kubeadm, kubelet, kubectl, containerd)
[TASK 6] 유틸리티 설치 (helm, net-tools, tcpdump, jq, etc.)
```

#### 2. cilium-ctr.sh (Control Plane)

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

#### 3. cilium-w.sh (Worker)

```
[TASK 1] kubeadm join 실행
```

#### 4. cilium-r.sh (Router)

```
[TASK 0] eth2 네트워크 인터페이스 설정
[TASK 1] 프로파일 설정
[TASK 2] AppArmor/UFW 비활성화
[TASK 3] IP Forwarding 활성화
[TASK 4] Dummy 인터페이스 생성 (loop1, loop2)
[TASK 5] 네트워크 유틸리티 설치
[TASK 6] Apache 웹서버 설치 (테스트용)
```

#### 5. ceph.sh (Ceph Node)

```
[TASK 1] 프로파일 설정
[TASK 2] AppArmor/UFW 비활성화
[TASK 3] /etc/hosts DNS 설정
[TASK 4] chrony, docker 설치
[TASK 5] cephadm 설치 (reef 버전)
[TASK 6] SSH 설정 (root 로그인 허용)
```


## 2. OpenVPN — Home Lab ↔ OCI 연결

### Nginx 서브도메인 라우팅

| 외부 URL                  | 포트 | 서비스      | 내부 포트 |
| ------------------------- | ---- | ----------- | --------- |
| vscode.container-wave.com | 443  | Code Server | :8080     |
| www.container-wave.com    | 443  | Sample App  | :9000     |
| cicd.container-wave.com   | 443  | ArgoCD      | :8443     |
| cicd.container-wave.com   | 8080 | Jenkins     | :18080    |
| cicd.container-wave.com   | 8081 | Nexus       | :18081    |
| mgmt.container-wave.com   | 443  | Grafana     | :80       |

## 3. SSL 인증서 자동 갱신

Let's Encrypt Wildcard 인증서(`*.container-wave.com`) 갱신 스크립트.

```bash
# 수동 실행
bash script/certrenew.sh

# cron 등록 (매월 1일 03:00)
0 3 1 * * /path/to/certrenew.sh >> /var/log/certrenew.log 2>&1
```

## Related

- [vagrant/README.md](./vagrant/README.md)
- [openvpn/README.md](./openvpn/README.md)
- [Nginx Let's Encrypt 인증서 적용](https://engineer-diarybook.tistory.com/entry/Nginx-Lets-Encryption-%EB%AC%B4%EB%A3%8C-%EC%9D%B8%EC%A6%9D%EC%84%9C-%EC%83%9D%EC%84%B1-%EB%B0%8F-HTTPS-%EC%A0%81%EC%9A%A9)
- [Nginx Reverse Proxy 설정](https://engineer-diarybook.tistory.com/entry/Nginx-Reverse-Proxy-%EC%84%A4%EC%A0%95-1)
