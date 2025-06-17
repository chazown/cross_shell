#!/bin/bash
set -e

# -------------------------------
# 컬러 출력 함수
# -------------------------------
log()   { echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

# -------------------------------
# sudo 권한 체크
# -------------------------------
if ! sudo -v; then
    error "sudo 권한이 필요합니다. 관리자 권한으로 실행하세요."
    exit 1
fi

# -------------------------------
# 배포판 정보 감지
# -------------------------------
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID=$ID
    DISTRO_VERSION_ID=$VERSION_ID
    ID_LIKE=${ID_LIKE,,}
else
    error "/etc/os-release 파일이 없어 배포판을 감지할 수 없습니다."
    exit 1
fi
log "감지된 배포판: $DISTRO_ID $DISTRO_VERSION_ID"

# -------------------------------
# Docker 설치 여부 확인
# -------------------------------
if command -v docker >/dev/null 2>&1; then
    log "Docker가 이미 설치되어 있습니다."
    docker --version
    docker compose version >/dev/null 2>&1 && docker compose version || \
    docker-compose version >/dev/null 2>&1 && docker-compose version || \
    warn "Docker Compose가 설치되어 있지 않거나 감지되지 않았습니다."
    exit 0
fi

# -------------------------------
# Debian 계열 Docker 설치 함수
# -------------------------------
install_docker_debian() {
    log "Debian/Ubuntu 계열에서 Docker 설치 중..."

    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release

    # GPG 키 등록
    DOCKER_GPG_URL="https://download.docker.com/linux/${DISTRO_ID}/gpg"
    sudo install -d -m 0755 /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        curl -fsSL "$DOCKER_GPG_URL" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
    else
        log "GPG 키가 이미 등록되어 있습니다."
    fi

    # 저장소 등록
    if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
        RELEASE_CODENAME=$(lsb_release -cs 2>/dev/null || echo "${VERSION_CODENAME:-bookworm}")
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRO_ID} ${RELEASE_CODENAME} stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    else
        log "Docker 저장소가 이미 존재합니다."
    fi

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
}

# -------------------------------
# RHEL 계열 Docker 설치 함수
# -------------------------------
install_docker_rhel() {
    log "RHEL 계열에서 Docker 설치 중..."

    # dnf가 있으면 dnf, 없으면 yum 사용
    if command -v dnf >/dev/null 2>&1; then
        PKG_MGR=dnf
    elif command -v yum >/dev/null 2>&1; then
        PKG_MGR=yum
    else
        error "dnf 또는 yum 패키지 관리자가 시스템에 없습니다."
        exit 1
    fi

    sudo $PKG_MGR -y install dnf-plugins-core curl

    if [ ! -f /etc/yum.repos.d/docker-ce.repo ]; then
        sudo $PKG_MGR config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    else
        log "Docker 저장소가 이미 존재합니다."
    fi

    sudo $PKG_MGR install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
}

# -------------------------------
# 배포판에 따른 설치 함수 호출
# -------------------------------
if [[ "$ID_LIKE" == *"debian"* || "$DISTRO_ID" == "debian" || "$DISTRO_ID" == "ubuntu" ]]; then
    install_docker_debian
elif [[ "$ID_LIKE" == *"rhel"* || "$DISTRO_ID" == "rocky" || "$DISTRO_ID" == "almalinux" || "$DISTRO_ID" == "centos" ]]; then
    install_docker_rhel
else
    error "지원하지 않는 배포판입니다: $DISTRO_ID"
    exit 1
fi

# -------------------------------
# Docker 서비스 상태 확인
# -------------------------------
log "Docker 서비스 상태 확인 중..."
sudo systemctl status docker --no-pager || true

# -------------------------------
# 현재 사용자 찾기 (sudo 실행 시 원래 사용자)
# -------------------------------
if [ -n "$SUDO_USER" ]; then
    CURRENT_USER="$SUDO_USER"
else
    CURRENT_USER=$(whoami)
fi

# -------------------------------
# docker 그룹에 사용자 추가
# -------------------------------
if getent group docker >/dev/null 2>&1; then
    sudo usermod -aG docker "$CURRENT_USER"
    log "사용자 '$CURRENT_USER'를 docker 그룹에 추가했습니다."
else
    warn "'docker' 그룹이 존재하지 않아 사용자 추가를 건너뜁니다."
fi

# -------------------------------
# 설치 완료 메시지
# -------------------------------
log "Docker 설치가 완료되었습니다."
docker --version
docker compose version >/dev/null 2>&1 && docker compose version || \
docker-compose version >/dev/null 2>&1 && docker-compose version || \
warn "Docker Compose가 설치되어 있지 않거나 감지되지 않았습니다."

warn "설치 후 로그아웃/로그인 후 'sudo' 없이 docker 명령어를 사용할 수 있습니다."
