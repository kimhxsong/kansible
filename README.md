# Kansible - Kubernetes 클러스터 자동 구성

Vagrant와 Ansible을 사용하여 다중 노드 Kubernetes 클러스터를 자동으로 구성하는 프로젝트입니다.

## 사전 요구사항

시작하기 전에 다음 소프트웨어가 설치되어 있는지 확인하세요:

- [Vagrant](https://www.vagrantup.com/downloads)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)

## 프로젝트 설정

1. **저장소 클론:**
   ```sh
   git clone <your-repo-url>
   cd kansible
   ```

2. **Ubuntu ISO 다운로드:**
   이 프로젝트는 VM 생성을 위해 `ubuntu-24.04.2-live-server-arm64.iso` 파일이 필요합니다. 다음 명령어로 자동 다운로드할 수 있습니다:
   ```sh
   make download-iso
   ```
   또는 수동으로 다운로드하여 프로젝트 루트 디렉터리에 배치하세요.

## 사용법

이 프로젝트는 모든 일반적인 작업을 간소화하기 위해 `Makefile`을 사용합니다.

- **클러스터 생성 (VM + Kubernetes 구성):**
  ```sh
  make all
  ```

- **클러스터 구성 없이 VM만 시작:**
  ```sh
  make up
  ```

- **이미 실행 중인 VM에 Kubernetes 구성:**
  ```sh
  make cluster
  ```

- **모든 VM 삭제 및 환경 정리:**
  ```sh
  make destroy
  ```

- **클러스터 상태 확인:**
  ```sh
  make validate
  ```

- **마스터 노드에 SSH 접속:**
  ```sh
  make ssh-master
  ```

## 🖥️ 개발 환경

- **호스트 OS**: macOS 15.5 (24F74) - Apple Silicon (ARM64)
- **VirtualBox**: 7.1.8r168469
- **게스트 OS**: Ubuntu 24.04.2 LTS Server (ARM64)
- **VM Box**: net9/ubuntu-24.04-arm64 v1.1
- **ISO**: ubuntu-24.04.2-live-server-arm64.iso

## 📋 시스템 요구사항

### 필수 소프트웨어
- **VirtualBox 7.1+** (ARM64 지원)
- **Vagrant 2.3+**
- **Ansible 2.9+**
- **Vagrant 플러그인**:
  - `vagrant-disksize` (디스크 크기 관리)
  - `vagrant-vbguest` (Guest Additions 관리)

### 하드웨어 요구사항
- **RAM**: 최소 12GB (호스트 4GB + 클러스터 8GB)
- **디스크**: 최소 20GB 여유 공간
- **CPU**: 4코어 이상 권장

## 🏗️ 클러스터 구성

### 노드 정보
| 노드명 | IP 주소 | RAM | CPU | 디스크 | 역할 |
|--------|---------|-----|-----|--------|------|
| k8s-master | 192.168.127.128 | 4GB | 4 cores | 50GB | Control Plane |
| k8s-worker1 | 192.168.127.129 | 2GB | 2 cores | 50GB | Worker Node |
| k8s-worker2 | 192.168.127.130 | 2GB | 2 cores | 50GB | Worker Node |
| k8s-worker3 | 192.168.127.131 | 2GB | 2 cores | 50GB | Worker Node |

### 네트워크 구성
- **호스트 전용 네트워크**: 192.168.127.0/24
- **Pod CIDR**: 10.244.0.0/16 (Flannel CNI)
- **서비스 CIDR**: 10.96.0.0/12

## 🚀 빠른 시작

### 1. 사전 준비
```bash
# Vagrant 플러그인 설치
vagrant plugin install vagrant-disksize
vagrant plugin install vagrant-vbguest

# 프로젝트 클론 및 이동
git clone <repository-url>
cd kansible
```

### 2. 클러스터 구성 

#### 방법 1: Makefile 사용 (자동화)
```bash
# 한 번에 모든 과정 실행
make all         # VM 생성 + 클러스터 구성

# 또는 단계별 실행
make up          # VM 생성 및 시작
make cluster     # Kubernetes 클러스터 구성
make validate    # 클러스터 상태 검증
```

#### 방법 2: 수동 실행 (Makefile 미사용)
```bash
# 1단계: VM 생성 및 시작
vagrant up

# 2단계: Ansible 플레이북 순서대로 실행
ansible-playbook -i ansible/inventory.ini ansible/configure-cluster.yml

# 3단계: 클러스터 상태 검증
vagrant ssh k8s-master -c "kubectl get nodes -o wide"
vagrant ssh k8s-master -c "kubectl get pods -n kube-system"
```

### 3. 클러스터 검증
```bash
# Makefile 사용
make validate

# 또는 직접 SSH 접속하여 확인
make ssh-master
kubectl get nodes -o wide
kubectl get pods -n kube-system

# 수동 확인
vagrant ssh k8s-master -c "kubectl get nodes -o wide"
vagrant ssh k8s-master -c "kubectl get pods -n kube-system"
```

## 📚 상세 사용법

### Vagrant 명령어
```bash
# VM 관리
make up          # 모든 VM 시작
make down        # 모든 VM 종료  
make status      # VM 상태 확인
make destroy     # VM 삭제 및 정리
```

### Ansible 명령어
```bash
# 클러스터 관리
make cluster     # 클러스터 구성
make reset       # 클러스터 초기화
make validate    # 상태 검증
```

### 테스트 및 디버깅
```bash
# 테스트 애플리케이션 배포
make deploy-test

# 개별 노드 SSH 접속
make ssh-master
make ssh-worker1
make ssh-worker2
make ssh-worker3

# 로그 확인
make logs
```

## 🔧 Ansible 플레이북 구조

### 주요 플레이북
- **`configure-cluster.yml`**: 클러스터 전체 구성
  - 공통 설정 (모든 노드)
  - 마스터 노드 초기화
  - 워커 노드 조인
  - 클러스터 검증

- **`reset-cluster.yml`**: 클러스터 초기화
- **`configure-network.yml`**: 네트워크 설정
- **`add-node.yml`**: 새 노드 추가
- **`roll-back.yml`**: 롤백 작업

### 인벤토리 구성
```ini
[k8s_cluster]
k8s-master ansible_host=192.168.127.128
k8s-worker1 ansible_host=192.168.127.129
k8s-worker2 ansible_host=192.168.127.130
k8s-worker3 ansible_host=192.168.127.131

[k8s_master]
k8s-master

[k8s_workers]
k8s-worker1
k8s-worker2
k8s-worker3
```

## 🔄 일반적인 워크플로우

### 1. 최초 환경 구성
```bash
# Makefile 사용
make all

# 수동 실행
vagrant up
ansible-playbook -i ansible/inventory.ini ansible/configure-cluster.yml
```

### 2. 기존 환경 시작
```bash
# Makefile 사용
make up
make validate

# 수동 실행
vagrant up
vagrant ssh k8s-master -c "kubectl get nodes"
```

### 3. 클러스터 재구성
```bash
# Makefile 사용
make reset
make cluster
make validate

# 수동 실행
ansible-playbook -i ansible/inventory.ini ansible/reset-cluster.yml
ansible-playbook -i ansible/inventory.ini ansible/configure-cluster.yml
vagrant ssh k8s-master -c "kubectl get nodes -o wide"
```

### 4. 개발 완료 후 정리
```bash
# Makefile 사용
make down     # 일시 정지
make destroy  # 완전 삭제

# 수동 실행
vagrant halt     # 일시 정지
vagrant destroy  # 완전 삭제
```

## 🐛 문제 해결

### 일반적인 문제들

#### VM 부팅 실패
```bash
# VirtualBox 상태 확인
VBoxManage list runningvms

# Vagrant 상태 확인
vagrant status

# VM 재시작
make down && make up
# 또는 수동으로
vagrant halt && vagrant up
```

#### SSH 연결 실패
```bash
# SSH 키 권한 확인
ls -la .vagrant/machines/*/virtualbox/private_key

# 수동 SSH 연결 테스트
vagrant ssh k8s-master
```

#### 클러스터 구성 실패
```bash
# 클러스터 완전 초기화
make reset

# 로그 확인
make logs
# 또는 수동으로
vagrant ssh k8s-master -c "sudo journalctl -u kubelet -f"

# 재구성
make cluster
```

#### 네트워크 연결 문제
```bash
# VM 네트워크 설정 확인
vagrant ssh k8s-master -c "ip route"

# 노드 간 연결 테스트
vagrant ssh k8s-master -c "ping 192.168.127.129"
```

### 로그 위치
- **Vagrant 로그**: `vagrant.log`
- **Kubelet 로그**: `/var/log/kubelet.log` (각 노드)
- **시스템 로그**: `sudo journalctl -u kubelet`

## 📖 참고 자료

- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [Vagrant 공식 문서](https://www.vagrantup.com/docs)
- [Ansible 공식 문서](https://docs.ansible.com/)
- [VirtualBox ARM64 지원](https://www.virtualbox.org/wiki/Mac%20OS%20X%20build%20instructions)

## 🤝 기여하기

1. 이슈 생성
2. 브랜치 생성 (`git checkout -b feature/amazing-feature`)
3. 커밋 (`git commit -m 'Add some amazing feature'`)
4. 푸시 (`git push origin feature/amazing-feature`)
5. Pull Request 생성

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.