# Kansible - Kubernetes 클러스터 자동 구성

Vagrant와 Ansible을 사용하여 다중 노드 Kubernetes 클러스터를 자동으로 구성하는 프로젝트입니다.

## 실행 환경 및 요구사항

### 소프트웨어 요구사항
- **VirtualBox 7.1+** (ARM64 지원)
- **Vagrant 2.3+**
- **Ansible 2.9+**
- **기타**: `git`, `curl`

> **Note**: AMD64/Intel (x86_64) 아키텍처 사용자 안내
> 
> 이 프로젝트는 Apple Silicon (ARM64) 환경에서 기본 설정되어 있습니다. 만약 AMD64/Intel 기반의 호스트를 사용하신다면, `Vagrantfile`의 `config.vm.box` 설정을 자신의 환경에 맞는 Box로 변경해야 합니다.
> 
> ```ruby
> # Vagrantfile
> config.vm.box = "net9/ubuntu-24.04-arm64" # 이 부분을 amd64용 Box로 변경
> ```
> 
> 호환되는 Box는 [Vagrant Cloud](https://portal.cloud.hashicorp.com/vagrant/discover)에서 `ubuntu` 등으로 검색하여 찾을 수 있습니다. (예: `ubuntu/noble64`)
> 
> Ansible 플레이북은 아키텍처를 자동으로 감지하므로 별도의 수정이 필요 없습니다.

### 하드웨어 요구사항
- **RAM**: 최소 12GB (호스트 4GB + 클러스터 8GB)
- **디스크**: 최소 20GB 여유 공간
- **CPU**: 4코어 이상 권장

## 설치 및 설정

1. **저장소 클론:**
   ```sh
   git clone https://github.com/kimhxsong/kansible
   cd kansible
   ```

2. **Ubuntu ISO 다운로드 (필요 시):**
   `Vagrantfile`에서 `config.vm.box`가 설정된 경우 이 단계는 필요 없습니다. 로컬 ISO 파일을 직접 사용하려면 아래 명령어로 다운로드하세요.
   ```sh
   make download-iso
   ```
   다운로드된 `ubuntu-24.04.2-live-server-arm64.iso` 파일은 프로젝트 루트에 위치해야 합니다.

## 🚀 빠른 시작

모든 준비가 완료되었다면, 다음 명령어 하나로 전체 클러스터를 생성하고 구성할 수 있습니다.

```bash
# VM 생성부터 Kubernetes 클러스터 구성까지 한 번에 실행
make all
```

프로세스가 완료되면, `make validate` 명령어로 클러스터 상태를 확인할 수 있습니다.

## 📚 상세 사용법

### 방법 1: Makefile 사용 (권장)

이 프로젝트는 모든 일반적인 작업을 간소화하기 위해 `Makefile`을 사용합니다.

#### 주요 명령어
- **클러스터 전체 생성:**
  ```sh
  make all
  ```
- **VM만 시작:**
  ```sh
  make up
  ```
- **실행 중인 VM에 Kubernetes 구성:**
  ```sh
  make cluster
  ```
- **클러스터 상태 확인:**
  ```sh
  make validate
  ```
- **클러스터 초기화:**
  ```sh
  make reset
  ```
- **모든 VM 삭제 및 환경 정리:**
  ```sh
  make destroy
  ```

#### SSH 접속 및 기타 명령어
- **마스터 노드 접속:** `make ssh-master`
- **워커 노드 접속:** `make ssh-worker1`, `make ssh-worker2`, ...
- **Kubelet 로그 확인:** `make logs`
- **테스트 앱 배포:** `make deploy-test`

### 방법 2: 수동 실행

`Makefile`을 사용하지 않고 각 단계를 직접 실행할 수도 있습니다.

1. **VM 생성 및 시작:**
   ```bash
   vagrant up
   ```

2. **Ansible 플레이북 실행:**
   ```bash
   ansible-playbook -i ansible/inventory.ini ansible/configure-cluster.yml
   ```

3. **클러스터 상태 검증:**
   ```bash
   vagrant ssh k8s-master -c "kubectl get nodes -o wide"
   vagrant ssh k8s-master -c "kubectl get pods -n kube-system"
   ```

### 일반적인 워크플로우 시나리오

- **최초 환경 구성:**
  `make all`

- **중단했던 환경 다시 시작:**
  `make up` 실행 후 `make validate`로 상태 확인

- **클러스터 재구성:**
  `make reset` -> `make cluster` -> `make validate`

- **개발 완료 후 정리:**
  - 일시 정지: `make down`
  - 완전 삭제: `make destroy`

## 🐛 문제 해결

### VM 부팅 또는 SSH 연결 실패
- **해결책 1: VM 재시작**
  ```bash
  make down && make up
  ```
- **해결책 2: 수동 SSH 연결 테스트**
  ```bash
  vagrant ssh k8s-master
  ```
  이때 발생하는 오류 메시지를 확인하여 문제를 진단합니다.

### 클러스터 구성 실패
- **해결책 1: 클러스터 완전 초기화 후 재구성**
  ```bash
  make reset
  make cluster
  ```
- **해결책 2: Kubelet 로그 확인**
  마스터 노드에 접속하여 `sudo journalctl -u kubelet -f` 명령어로 실시간 로그를 확인합니다.
  ```bash
  make logs
  ```

### 네트워크 연결 문제
- **노드 간 Ping 테스트:**
  ```bash
  vagrant ssh k8s-master -c "ping 192.168.127.129"
  ```
- **라우팅 테이블 확인:**
  ```bash
  vagrant ssh k8s-master -c "ip route"
  ```

## ⚙️ 기술 사양

### 개발 환경
- **호스트 OS**: macOS 15.5 (24F74) - Apple Silicon (ARM64)
- **VirtualBox**: 7.1.8r168469
- **게스트 OS**: Ubuntu 24.04.2 LTS Server (ARM64)
- **VM Box**: net9/ubuntu-24.04-arm64 v1.1
- **ISO**: ubuntu-24.04.2-live-server-arm64.iso

### 소프트웨어 버전
- **Kubernetes**: v1.33.2 (2024년 12월 기준 최신 안정 버전)
  - Ansible 플레이북이 `https://dl.k8s.io/release/stable.txt`에서 최신 안정 버전을 자동으로 가져옴
  - kubelet, kubeadm, kubectl 모두 동일한 버전으로 설치
- **Container Runtime**: containerd (Ubuntu 패키지 저장소)
- **CNI**: Flannel (최신 릴리즈 버전)
- **Ansible**: 2.9+ (호스트에 설치)

### 클러스터 아키텍처
![](./image.png)


### 네트워크 구성
- **호스트 전용 네트워크**: 192.168.127.0/24
- **Pod CIDR**: 10.244.0.0/16 (Flannel CNI)
- **서비스 CIDR**: 10.96.0.0/12

### Ansible 플레이북 구조
- **`configure-network.yml`**: 네트워크 설정
- **`configure-cluster.yml`**: 클러스터 전체 구성 (공통 설정, 마스터 초기화, 워커 조인)
- **`reset-cluster.yml`**: 클러스터 초기화


## 📖 참고 자료

- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [Vagrant 공식 문서](https://www.vagrantup.com/docs)
- [Ansible 공식 문서](https://docs.ansible.com/)

