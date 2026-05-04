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

## Prerequisites

| 항목 | 버전 |
|------|------|
| VirtualBox | 7.x |
| Vagrant | 2.x |

---

## 1. Vagrant — VM 프로비저닝

→ **[vagrant/README.md](./vagrant/README.md)**

### 실행

```bash
cd vagrant/
vagrant up          # 전체 VM 생성 + K8s 클러스터 구성
vagrant halt        # VM 정지
vagrant destroy -f  # VM 전체 삭제
```

### 주요 버전 (Vagrantfile)

```ruby
K8SV            = '1.33.2'
K8S_APT_VERSION = '1.33.2-1.1'
CONTAINERDV     = '1.7.27-1'
CILIUMV         = '1.18.0'
```

### VM 구성

| 노드 | 역할 | vCPU | Memory | IP |
|------|------|:----:|:------:|-----|
| cilium-ctr | K8s Control Plane | 2 | 4GB | 192.168.10.100 |
| cilium-w1, w2 | K8s Worker | 2 | 4GB | 192.168.10.101~102 |
| cilium-w3 | K8s Worker (Standby) | 2 | 4GB | 192.168.20.100 |
| cilium-r | Router | 1 | 1GB | 192.168.10.200 · 192.168.20.200 |
| ceph-01~03 | Ceph OSD (Standby) | 2 | 4GB | 192.168.10.201~203 |

### 네트워크 구성

| 구분 | CIDR | 용도 |
|------|------|------|
| Subnet1 | 192.168.10.0/24 | K8s Primary (ctr, w1, w2, router, ceph) |
| Subnet2 | 192.168.20.0/24 | K8s Secondary (w3, router) |
| Pod CIDR | 172.20.0.0/16 | Cilium Pod Network |
| Service CIDR | 10.96.0.0/16 | K8s Service |
| LB Pool | 192.168.10.240-255 | Cilium L2 Announcement |
| Ceph Public | 192.168.50.0/24 | 클라이언트 → OSD |
| Ceph Cluster | 192.168.60.0/24 | OSD 간 복제/복구 |

---

## 2. OpenVPN — Home Lab ↔ OCI 연결

→ **[openvpn/README.md](./openvpn/README.md)**

### 외부 접근 흐름

```
브라우저
  → OCI VM (Nginx · Let's Encrypt TLS)
    → OpenVPN 터널 (암호화)
      → Mini-PC (192.168.200.2)
        → 내부 서비스
```

### Nginx 서브도메인 라우팅

| 외부 URL | 포트 | 서비스 | 내부 포트 |
|----------|------|--------|---------|
| vscode.container-wave.com | 443 | Code Server | :8080 |
| www.container-wave.com | 443 | Sample App | :9000 |
| cicd.container-wave.com | 443 | ArgoCD | :8443 |
| cicd.container-wave.com | 8080 | Jenkins | :18080 |
| cicd.container-wave.com | 8081 | Nexus | :18081 |
| mgmt.container-wave.com | 443 | Grafana | :80 |

---

## 3. SSL 인증서 자동 갱신

Let's Encrypt Wildcard 인증서(`*.container-wave.com`) 갱신 스크립트.

```bash
# 수동 실행
bash script/certrenew.sh

# cron 등록 (매월 1일 03:00)
0 3 1 * * /path/to/certrenew.sh >> /var/log/certrenew.log 2>&1
```

---

## Related

- [vagrant/README.md](./vagrant/README.md)
- [openvpn/README.md](./openvpn/README.md)
- [Nginx Let's Encrypt 인증서 적용](https://engineer-diarybook.tistory.com/entry/Nginx-Lets-Encryption-%EB%AC%B4%EB%A3%8C-%EC%9D%B8%EC%A6%9D%EC%84%9C-%EC%83%9D%EC%84%B1-%EB%B0%8F-HTTPS-%EC%A0%81%EC%9A%A9)
- [Nginx Reverse Proxy 설정](https://engineer-diarybook.tistory.com/entry/Nginx-Reverse-Proxy-%EC%84%A4%EC%A0%95-1)
