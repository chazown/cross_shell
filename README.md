# cross_shell

## 🐧 Linux Automation Shell Script — 기본 환경 자동화

이 스크립트는 **Rocky Linux (CentOS/RHEL 계열)**와 **Ubuntu/Debian 계열** 리눅스 배포판을 자동으로 감지하여, 아래 작업들을 한 번에 처리합니다.

### 주요 기능

- **OS 자동 감지**: Rocky Linux와 Ubuntu/Debian을 구분해 맞춤 설치 및 설정 적용  
- **중복 설치 방지**: 이미 설치된 패키지는 재설치하지 않고 자동으로 건너뜀  
- **필수 패키지 설치**: curl, git, vim, htop, wget, net-tools, tar, gzip, bzip2, openssh-server, bind9, samba, vsftpd, isc-dhcp-server  
- **시스템 업데이트**: 패키지 목록 업데이트 및 업그레이드 자동 실행  
- **SSH 서버 활성화 및 설정 변경**  
  - root 로그인 허용 (`PermitRootLogin yes`)  
  - SSH 서비스 자동 시작 및 활성화  
- **SELinux 설정**: SELinux가 활성화된 경우, `Permissive` 모드로 전환  
- **방화벽 설정**: Rocky Linux에서 firewalld 서비스 비활성화  
- **Anaconda 설치 및 환경 구성**  
  - 최신 Anaconda 설치 (미설치 시 자동 다운로드 및 설치)  
  - Conda 초기화 및 기본 업데이트  
  - Jupyter Notebook 설치  

### 사용 방법

```bash
git clone https://github.com/ycl/cross_shell.git
cd cross_shell
chmod +x base-setup.sh
./base-setup.sh
