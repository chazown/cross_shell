#!/bin/bash
set -e

ANACONDA_PATH="$HOME/anaconda3"
ANACONDA_INSTALLER="Anaconda3-2024.10-1-Linux-x86_64.sh"

# Anaconda 설치 확인
if [ -d "$ANACONDA_PATH" ] && [ -x "$ANACONDA_PATH/bin/conda" ]; then
  echo "Anaconda가 이미 설치되어 있습니다. 설치를 건너뜁니다."
else
  echo "Anaconda 설치 중..."
  cd /tmp
  if wget https://repo.anaconda.com/archive/$ANACONDA_INSTALLER; then
    chmod +x $ANACONDA_INSTALLER
    ./$ANACONDA_INSTALLER -b -p "$ANACONDA_PATH"
  else
    echo "Anaconda 설치 파일 다운로드 실패!"
    exit 1
  fi
fi

# 환경변수 등록 (중복 등록 방지)
if ! grep -q 'export PATH="$HOME/anaconda3/bin:$PATH"' ~/.bashrc; then
  echo 'export PATH="$HOME/anaconda3/bin:$PATH"' >> ~/.bashrc
fi

# conda 초기화 및 기본 환경 자동 활성화 비활성화
"$ANACONDA_PATH/bin/conda" config --set auto_activate_base false
"$ANACONDA_PATH/bin/conda" init bash

# 쉘 설정 적용
source ~/.bashrc

# conda 업데이트
"$ANACONDA_PATH/bin/conda" update -n base -c defaults conda -y

# Jupyter Notebook 설치
"$ANACONDA_PATH/bin/conda" install -y notebook

echo "Anaconda 및 Jupyter Notebook 설치 완료!"
echo "환경변수를 적용하려면 터미널을 재시작하거나 'source ~/.bashrc'를 실행하세요."
