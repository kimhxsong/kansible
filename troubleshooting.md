# 트러블 슈팅 내용 정리

Vagrant, Ansible, Kubernetes 클러스터 구축 과정에서 발생한 주요 오류와 해결 과정

## 목차
**Part 1: VM 환경 설정 오류 (Vagrant & VirtualBox)**
- 문제 1: NS_ERROR_FAILURE - CPU 아키텍처 불일치

**Part 2: 프로비저닝 오류 (Ansible & Jinja2)**
- 문제 2: Jinja2 버전 문자열 자동 형 변환
- 문제 3: APT 캐시 만료로 인한 패키지 설치 실패

**Part 3: 쿠버네티스 클러스터 오류 (k8s)**
- 문제 4: 바이너리 직접 다운로드 방식으로의 전환
- 문제 5: Exec format error - 아키텍처 불일치
- 문제 6: iptables 초기화로 인한 네트워크 접속 불가
- 문제 7: 게이트웨이 충돌로 인한 라우팅 문제
- 문제 8: ansible_default_ipv4 변수 감지 오류
- 문제 9: 워커 노드 조인 타임아웃
- 문제 10: kubectl 설정 오류 (localhost:8080)

---

## Part 1: VM 환경 설정 오류 (Vagrant & VirtualBox)

### 문제 1: The VM session was aborted (NS_ERROR_FAILURE)

**현상**: vagrant up 실행 시 VM이 부팅되지 않고 세션 중단 오류 발생

**시도 과정**:
- LLM을 통해 생성한 Vagrantfile을 기반으로 ubuntu/jammy64 Box 사용
- 오류 메시지를 기반으로 리소스, 권한, 재설치 등 일반적인 해결책을 시도했으나 실패

**근본 원인**: 호스트 시스템(Apple Silicon, arm64)과 가상머신 Box(amd64) 간의 CPU 아키텍처 불일치

**해결책**:
```bash
# 호스트 아키텍처 확인
uname -m

# arm64를 지원하는 Box로 교체
config.vm.box = "net9/ubuntu-24.04-arm64"
```

**분석 및 교훈**: 대부분의 표준 Vagrant Box는 amd64를 기본으로 제공한다. ARM64 환경에서 AI로 인프라를 구성할 경우, 생성된 설정 파일의 아키텍처 호환성을 직접 확인해야 한다.

---

## Part 2: 프로비저닝 오류 (Ansible & Jinja2)

### 문제 2: Jinja2 템플릿에서 버전 문자열 .0이 잘리는 현상

**현상**: `k8s_version: "1.33.0"` 변수가 템플릿에서 1.33으로 변환됨

**원인**: Jinja2가 숫자 형태의 문자열을 float으로 자동 형 변환

**해결책**: 
```yaml
version: {{ k8s_version | string }}
```

**분석 및 정리**: 이 현상이 직접적인 실패로 이어지지는 않았지만, 의도치 않은 버전 설치를 유발할 수 있는 잠재적 위험 요인이다.

Jinja2의 자동 형 변환은 때로 의도적으로 활용되기도 한다. 예를 들어 `port: "8080"`을 템플릿에서 숫자로 사용하려는 경우가 그렇다. 하지만 문제가 되는 경우도 있다:

- **문제 사례**: `version: "3.0"` → 3 (마이너 버전 정보 손실)
- **문제 사례**: `tag: "1.20"` → 1.2 (Docker 태그에서 의미 변경)
- **문제 사례**: `ip: "192.168.1.10"` → 문자열 유지 (문제없음)

버전이나 태그처럼 정확한 문자열 보존이 중요한 경우에는 `| string` 필터를 명시적으로 사용하여 예상치 못한 형 변환을 방지해야 한다.

### 문제 3: APT 캐시 만료로 인한 패키지 설치 실패

**현상**: apt 모듈로 패키지 설치 시 404 Not Found 에러가 간헐적으로 발생

**원인**: apt 모듈 사용 시 `update_cache: no`로 설정되어 캐시 유효 기간이 만료되었고, 패키지 메타데이터가 오래된 상태

**해결책**: 플레이북 실행 시 항상 최신 패키지 목록을 가져오도록 `update_cache: yes`로 변경

```yaml
- name: Install required packages
  apt:
    name: "{{ item }}"
    state: present
    update_cache: yes
  loop:
    - apt-transport-https
    - ca-certificates
```

**정리**: Ansible의 apt 모듈 사용 시 `update_cache: yes`로 설정하여 캐시 문제로 인한 실패를 예방하는 것이 안정적이다. 다만 다음과 같은 경우에는 `update_cache: no`를 고려할 수 있다:

- **대량 배포 시**: 수십 대의 서버가 동시에 Ubuntu 저장소에 apt update 요청을 보내면 외부 저장소 서버에 순간적인 부하를 줄 수 있음 (각 VM은 개별적으로 자신의 로컬 캐시를 업데이트)
- **반복 실행 시**: 짧은 시간 내에 플레이북을 여러 번 실행하는 경우, 각 VM에서 매번 캐시를 업데이트하면 불필요한 네트워크 트래픽과 시간 소모가 발생
- **제한된 네트워크**: 인터넷 연결이 제한되거나 느린 환경에서는 각 VM의 캐시 업데이트 시간이 오래 걸릴 수 있음

이런 경우에는 플레이북 시작 부분에서 한 번만 apt update를 실행하고, 이후 설치 태스크에서는 `update_cache: no`를 사용하는 것이 효율적이다.

---

## Part 3: 쿠버네티스 클러스터 오류 (k8s)

### 문제 4: 바이너리 직접 다운로드 방식으로의 전환

**현상**: apt update 시 k8s 저장소의 GPG 공개 키 관련 인증 오류 발생

**해결책**: APT 저장소를 이용하는 대신, get_url 모듈로 바이너리를 직접 다운로드하는 방식으로 전환

**분석 및 교훈**:

**쿠버네티스 설치 방식의 변화** (팩트체크 완료):
- 2023년 9월 13일부터 쿠버네티스 프로젝트는 기존 Google 호스팅 저장소(apt.kubernetes.io, yum.kubernetes.io)를 중단하고 새로운 커뮤니티 소유 저장소(pkgs.k8s.io)로 전환
- 2024년 3월 4일에 기존 저장소가 완전히 제거되어 더 이상 접근할 수 없게 됨
- 현재 쿠버네티스 공식 문서는 바이너리 직접 다운로드와 APT 저장소 설치 방식을 모두 제공

**Ubuntu GPG 인증 강화** (팩트체크 완료):
- Ubuntu 20.10부터 apt-key 도구가 보안상의 이유로 deprecated되기 시작했으며, Ubuntu 22.04에서는 경고 메시지가 표시됨
- apt-key로 추가된 키는 시스템의 모든 저장소에서 무조건 신뢰되어 보안 위험을 초래할 수 있기 때문에, 각 저장소별로 개별 키를 지정하는 방식으로 변경됨
- 이로 인해 Docker, 쿠버네티스 등 서드파티 패키지 설치 시 GPG 키를 개별적으로 설정해야 하는 과정이 복잡해짐

**개인적 관찰과 추론**: 이러한 변화는 보안 강화가 주된 목적이지만, 개발자들에게는 설치 과정이 더 복잡해지는 결과를 가져왔다. 순수한 Ubuntu 베이스 이미지에서 시작해서 GPG 키 설정부터 패키지 설치까지 모든 과정을 직접 처리하는 것보다, python:3.11, node:18 같은 런타임이 미리 설치된 이미지를 사용하는 것이 이런 복잡성을 피할 수 있는 실무적 선택으로 느껴진다.

### 문제 5: Exec format error - 아키텍처 불일치

**현상**: 다운로드한 바이너리 실행 시 포맷 오류 발생

**해결책**: 
```bash
# 파일 타입 확인
file /usr/local/bin/kubeadm

# ARM64 시스템에 x86_64 바이너리가 다운로드된 것을 발견하고 아키텍처에 맞는 바이너리로 교체
```

**정리**: 파일이 있으나 실행이 안 될 경우, 권한 문제 다음으로 아키텍처 불일치를 의심해야 한다.

### 문제 6: iptables 초기화로 인한 네트워크 접속 불가

**현상**: "네트워크 초기화 스크립트" 실행 후 모든 노드에 SSH 접속 불가

**원인**: `iptables -F` 명령어가 SSH 접속 규칙을 포함한 시스템의 모든 방화벽 규칙을 삭제함

**배경**: 워커노드와 마스터노드의 IP를 변경할 때 충돌을 막기 위해 네트워크 초기화 스크립트를 LLM에 요청했으나, 생성된 스크립트가 과도하게 네트워크 설정을 초기화

**해결책**: `vagrant halt && vagrant up`으로 VM을 재시작

**분석 및 교훈**:

**Vagrant의 복구 메커니즘** (팩트체크 완료):

`vagrant reload`와 `vagrant up`의 설정 적용 차이:

**항상 적용되는 설정 (reload/up 시)**:
- 네트워크 설정: `config.vm.network` - 부팅할 때마다 재구성됨
- 포트 포워딩: 매번 새로 설정됨
- 공유 폴더: `config.vm.synced_folder` - 매번 마운트 재설정
- 호스트명: `config.vm.hostname` - 부팅 시 적용
- 프로비저닝: `--provision` 플래그 사용 시에만 실행

**VM 종료가 필요한 설정 (reload만 적용)**:
- CPU 수: `vb.cpus` - VirtualBox에서 VM이 종료된 상태에서만 변경 가능
- 메모리 크기: `vb.memory` - VirtualBox에서 VM이 종료된 상태에서만 변경 가능
- 디스플레이 설정: VRAM 크기 등
- 하드웨어 가상화 설정: VT-x/AMD-V, PAE/NX 등
- 저장소 컨트롤러: SATA, IDE 등 컨트롤러 변경

**원리**: VirtualBox는 VM이 실행 중일 때 하드웨어 관련 설정(CPU, 메모리 등)을 변경할 수 없도록 제한한다. 따라서 이런 설정들은 VM을 완전히 종료한 후 재시작해야 적용된다. 반면 네트워크나 공유 폴더 같은 설정은 부팅 과정에서 동적으로 구성할 수 있어 매번 새로 적용된다.

**요약**: 결국 VirtualBox 설정 창에서 VM이 종료(Powered Off) 상태일 때만 변경 가능한 모든 설정이 vagrant reload가 필요한 설정들이다.

- `vagrant up`: VM이 존재하지 않으면 생성하고, 이미 존재하면 부팅한다. 중요한 점은 VM을 부팅할 때마다 Vagrantfile의 네트워크 설정을 적용한다는 것이다.
- `vagrant reload`: 실행 중인 VM을 halt → up 순서로 재시작하며, Vagrantfile의 변경사항을 적용하기 위해 사용한다.

**네트워크 설정 적용**: Vagrant는 VM 부팅 과정에서 "Configuring and enabling network interfaces..." 단계를 통해 Vagrantfile에 정의된 네트워크 설정(`config.vm.network`)을 적용한다. 이는 새 VM 생성이든 기존 VM 재부팅이든 동일하게 수행된다.

**차이점**:
- `vagrant up`은 새로운 VM 생성 또는 기존 VM 부팅 + 네트워크 설정 적용
- `vagrant reload`는 기존 VM 재시작 + Vagrantfile 변경사항 적용 (네트워크 설정 포함)

두 명령어 모두 부팅 과정에서 네트워크 인터페이스를 Vagrantfile 설정에 따라 구성하므로, 이 경우 iptables로 삭제된 네트워크 설정이 복구된 것이다.

**실제 OS와의 차이**:
- 실제 Windows, Mac PC에서는 네트워크 설정을 과도하게 초기화했을 때의 복구 방식이 운영체제마다 다르다.
- Windows: 재부팅 시 일부 네트워크 설정이 레지스트리에서 복구될 수 있으나, 수동 설정한 고정 IP나 라우팅 테이블은 그대로 남아있을 가능성이 높다.
- macOS/Linux: iptables-persistent 등으로 규칙을 저장했다면 재부팅으로 복구되지 않을 수 있다.

**주의사항**: AI가 생성한 위험한 명령어는 실제 서버에서 실행 시 매우 신중해야 한다.

### 문제 7: 게이트웨이 충돌로 인한 라우팅 문제

**현상**: 노드에 IP를 2개(DHCP, 고정) 할당 후 외부에서 노드로 접속 시 응답이 오지 않음

**원인**:
- Ansible 호스트(클러스터 노드)당 IP를 두 개 할당: 하나는 인터넷용 DHCP, 하나는 내부통신용 고정 IP
- 고정 IP 설정 시 게이트웨이 주소를 설정했는데, 이것이 DHCP 게이트웨이와 동일한 네트워크에서 겹치면서 두 인터페이스 모두에 기본 게이트웨이가 설정되어 라우팅 충돌 발생

**세부 분석**:
- **문제 상황**: eth0(DHCP)와 eth1(고정 IP) 두 인터페이스 모두에 게이트웨이가 설정됨
- **DHCP 인터페이스(eth0)**: 자동으로 기본 게이트웨이 할당받음
- **고정 IP 인터페이스(eth1)**: `gateway4: 192.168.127.2`로 수동 설정

**라우팅 충돌의 실제 현상**:
- **요청(outbound) 전송**: 일반적으로 성공 (마지막에 설정된 기본 게이트웨이 사용)
- **응답(inbound) 수신**: 문제 발생 가능성 높음 - 외부에서 들어오는 응답 패킷이 어느 인터페이스로 와야 하는지 애매하거나, 응답이 다른 경로로 나가려 할 때 비대칭 라우팅(asymmetric routing) 발생
- **결과**: 연결이 설정되지 않거나 일부 패킷만 전달되어 네트워크 접속 불가 현상

**해결**: `#gateway4: 192.168.127.2` 주석 처리로 eth1의 게이트웨이 제거하여 eth0의 DHCP 게이트웨이만 사용하도록 설정

**해결책**:
- 기본 게이트웨이는 외부 인터넷과 연결되는 주 인터페이스에만 설정하고, 내부 통신용 인터페이스에서는 게이트웨이 설정을 제거
- **DHCP 주의사항**: DHCP를 사용하는 인터페이스는 자동으로 기본 게이트웨이를 설정받기 때문에, 수동으로 게이트웨이를 제거해도 DHCP 갱신 시 다시 설정될 수 있다. 이 경우 고정 IP 설정 시 게이트웨이를 명시적으로 제외하거나, DHCP 클라이언트 설정에서 기본 게이트웨이 옵션을 비활성화해야 한다.

**정리**: 하나의 서버에 여러 IP를 할당할 때, 기본 게이트웨이는 유일해야 한다.

### 문제 8: ansible_default_ipv4 변수 사용 실수

**현상**: kubeadm 초기화 시 `ansible_default_ipv4.address` 변수가 내부 통신용 IP가 아닌 Vagrant의 NAT IP로 설정됨

**원인**:
- Kubernetes API 서버용 IP로 마스터노드 IP를 지정하기 위해 `ansible_default_ipv4`를 사용
- 하지만 이 변수가 Vagrant NAT IP 주소로 자동 감지되어 의도와 다른 결과 발생

**해결책**: `hostvars[inventory_hostname]['ansible_host']` 처럼 Ansible 인벤토리에 명시적으로 정의된 IP 변수를 사용

**정리**: 자동 감지 변수는 여러 네트워크 인터페이스를 가진 환경에서 의도와 다른 IP를 감지할 수 있으므로, 명시적인 변수를 사용하는 것이 안전하다.

### 문제 9: 워커 노드 조인 타임아웃

**현상**: kubeadm join 태스크가 로그 없이 멈춤

**해결책**: shell 모듈에 async와 poll을 사용하여 타임아웃이 있는 비동기 실행으로 변경

```yaml
- name: Join worker nodes to cluster
  shell: kubeadm join {{ master_ip }}:6443 --token {{ token }} --discovery-token-ca-cert-hash {{ ca_hash }}
  async: 300  # 5분 타임아웃
  poll: 10    # 10초마다 상태 확인
```

**정리**: 이는 자동화 도구에서 매우 일반적인 실무 패턴이다. 외부 명령어나 네트워크 작업을 실행하는 모든 자동화 태스크에는 타임아웃을 설정해야 한다. 특히 다음과 같은 상황에서 필수적이다:

- 클러스터 조인/설정: 네트워크 지연이나 인증 문제로 무한 대기 가능
- 패키지 다운로드: 네트워크 상태에 따라 중단될 수 있음
- 서비스 시작/중지: 의존성 문제로 멈출 수 있음
- 외부 API 호출: 응답 지연이나 장애 상황 대비

### 문제 10: kubectl 설정 오류 (localhost:8080)

**현상**: 워커 노드에서 kubectl 실행 시 localhost:8080 접속 거부 오류 발생

**실제 원인**:
- kubectl 명령어를 일반 사용자(vagrant)로 실행하면 `/home/vagrant/.kube/config` 파일을 찾음
- ansible 태스크 실패로 해당 경로에 파일 복사가 되지 않음
- kubectl이 기본값으로 localhost:8080에 접속을 시도

**해결책**:
- **임시 해결책**: `sudo kubectl` 사용 (root의 `/root/.kube/config` 파일 사용)
- **근본 해결책**: 

**실행 예시**:
```bash
# 실패: 일반 사용자 kubectl (config 파일 없음)
vagrant@k8s-master:~$ kubectl run nginx --image=nginx
Error: "couldn't get current server API group list: Get \"http://localhost:8080/api?timeout=32s\": dial tcp 127.0.0.1:8080: connect: connection refused"

# 성공: sudo kubectl (root config 사용)  
vagrant@k8s-master:~$ sudo kubectl run nginx --image=nginx
pod/nginx created
```

**정리**: kubectl의 localhost:8080 에러는 해당 사용자의 kubeconfig 파일이 없다는 의미다. sudo로 실행하면 root의 config를 사용하여 정상 동작한다.
