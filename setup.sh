#!/bin/bash
set -e

# OS 판별
OS=""
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
fi

echo "== [1] 시스템 업데이트 및 업그레이드 =="
if [[ "$OS" == "ubuntu" ]]; then
  sudo apt -y update && sudo apt -y upgrade
elif [[ "$OS" == "rocky" || "$OS" == "centos" || "$OS" == "fedora" ]]; then
  sudo dnf -y update && sudo dnf -y upgrade
else
  echo "지원하지 않는 OS입니다."
  exit 1
fi

echo "== [2] 기본 패키지 설치 =="
if [[ "$OS" == "ubuntu" ]]; then
  sudo apt -y install curl git vim htop build-essential wget net-tools openssh-server ufw bind9 samba vsftpd isc-dhcp-server
elif [[ "$OS" == "rocky" || "$OS" == "centos" || "$OS" == "fedora" ]]; then
  sudo dnf -y install epel-release
  sudo dnf -y install https://rpms.remirepo.net/enterprise/remi-release-9.rpm
  sudo dnf -y install curl git vim htop wget net-tools openssh-server bind-utils samba vsftpd dhcp-server
fi

echo "== [3] SELinux 비활성화 및 firewalld/ufw 비활성화 =="
if [[ "$OS" == "ubuntu" ]]; then
  sudo ufw disable || echo "ufw 비활성화 실패 혹은 없음"
  if command -v sestatus &> /dev/null; then
    sudo apt -y install policycoreutils
    sudo setenforce 0 || true
  fi
elif [[ "$OS" == "rocky" || "$OS" == "centos" || "$OS" == "fedora" ]]; then
  sudo setenforce 0 || true
  sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
  sudo systemctl disable firewalld --now || echo "firewalld 비활성화 실패 혹은 없음"
fi

echo "== [4] SSH 설정 =="
if [[ "$OS" == "ubuntu" ]]; then
  sudo systemctl enable ssh
  sudo systemctl start ssh
elif [[ "$OS" == "rocky" || "$OS" == "centos" || "$OS" == "fedora" ]]; then
  sudo sed -i 's/^\#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
  sudo systemctl enable sshd --now
  sudo systemctl reload sshd
fi
echo "SSH 포트 확인:"
sudo netstat -tulnp | grep ssh || true

echo "기본 시스템 설정 완료!"
