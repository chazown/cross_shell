#!/bin/bash

# --- 리눅스 호환성 강화 Bash 스크립트 ---

# 1. 초기 점검 (root 권한 확인)
if [ "$(id -u)" != "0" ]; then
   echo "🚨 오류: 이 스크립트는 'sudo'를 사용하여 root 권한으로 실행해야 합니다." >&2
   exit 1
fi

check_and_close_ports() {
    # 2. 열린 포트 스캔 및 중복 제거
    echo "--- 1단계: LISTENING 포트 스캔 및 프로세스 정보 확인 ---"

    # netstat 명령을 사용하여 TCP LISTENING 포트 정보 추출 (PID, Program Name 포함)
    # awk를 사용하여 IP:Port와 PID를 기반으로 고유한 정보만 추출하고 보기 좋게 포맷
    LISTENING_INFO=$(
        netstat -ntlp 2>/dev/null | awk '
        /LISTEN/ && $4 ~ /:/ {
            # $4: Local Address (IP:Port)
            # $7: PID/ProgramName
            
            # PID와 ProgramName 분리
            split($7, pid_prog, "/");
            pid = pid_prog[1];
            
            # $4 (IP:Port) 기준으로 고유한 LISTEN 포트만 출력
            if (!seen[$4]++) {
                printf "%s %s %s\n", $4, pid, pid_prog[2];
            }
        }' | sort -k2,2 | uniq
    )

    if [ -z "$LISTENING_INFO" ]; then
        echo "[✅ 완료] 현재 LISTENING 상태의 TCP 포트가 없습니다."
        return 0
    fi

    # 3. 위험도 구분 및 출력
    echo -e "\n--- 2단계: 잠재적 위험 포트 목록 (LocalAddress가 0.0.0.0 또는 IPv6 ::) ---"
    echo "ID | LocalPort | 바인딩 주소 | 프로세스 이름 (PID)"
    echo "----------------------------------------------------"

    RISK_PORTS=()
    i=1

    # while read 루프를 사용하여 안정적으로 줄 단위 처리
    echo "$LISTENING_INFO" | while read -r line; do
        local_addr=$(echo "$line" | awk '{print $1}')
        pid=$(echo "$line" | awk '{print $2}')
        prog_name=$(echo "$line" | awk '{print $3}')
        
        # 포트 번호 추출 (마지막 콜론 뒤의 값)
        local_port=$(echo "$local_addr" | awk -F: '{print $NF}')
        
        # 0.0.0.0, 0.0.0.0:*, ::: 에 바인딩된 포트만 잠재적 위험으로 분류
        if [[ "$local_addr" =~ "0.0.0.0" || "$local_addr" =~ ":::" ]]; then
            printf "%-2s | %-8s | %-12s | %s (%s)\n" "$i" "$local_port" "$local_addr" "$prog_name" "$pid"
            RISK_PORTS+=("$local_port")
            i=$((i+1))
        fi
    done
    
    # 4. 닫아야 되는 포트 번호 입력 및 확인
    if [ ${#RISK_PORTS[@]} -eq 0 ]; then
        echo "[✅ 안전] 외부 노출이 의심되는 포트가 없습니다."
        return 0
    fi
    
    echo -e "\n--- 3단계: 포트 차단 작업 ---"
    
    # 루프 시작 (추가 진행 여부에 따라 반복)
    while true; do
        echo "차단할 포트 번호(예: 135,445)를 입력하거나, 작업을 종료하려면 'n'을 입력하세요:"
        read -r INPUT_PORTS
        
        INPUT_PORTS=$(echo "$INPUT_PORTS" | tr -d '[:space:]') # 공백 제거

        if [[ "$INPUT_PORTS" =~ ^[nN]$ ]]; then
            break # 닫는 작업 종료
        fi

        # 쉼표로 구분된 포트 번호 처리
        # tr을 사용하여 쉼표를 공백으로 변환 후 배열로 읽음
        read -ra PORTS_TO_CLOSE <<< "$(echo "$INPUT_PORTS" | tr ',' ' ')"

        if [ ${#PORTS_TO_CLOSE[@]} -eq 0 ]; then
            echo "[오류] 포트 번호를 올바르게 입력해주세요 (예: 135,445)."
            continue
        fi

        echo -e "\n[최종 확인] 다음 포트들을 방화벽에서 인바운드 차단하시겠습니까?"
        echo -e "포트 목록: ${PORTS_TO_CLOSE[*]}"
        echo -n "차단을 진행하시려면 'y'를, 취소하려면 'n'을 입력하세요: "
        read -r CONFIRM_CLOSE

        if [[ "$CONFIRM_CLOSE" =~ ^[yY]$ ]]; then
            for p in "${PORTS_TO_CLOSE[@]}"; do
                # iptables (범용적인 리눅스 방화벽) 규칙 추가
                # TCP 프로토콜만 차단
                echo "-> 포트 $p (TCP)에 대한 인바운드 연결을 차단합니다."
                iptables -A INPUT -p tcp --dport "$p" -j DROP
                echo "[성공] 포트 $p 차단 규칙이 iptables에 추가되었습니다."
            done
            
            # 규칙 저장에 대한 안내 (시스템마다 명령어 다름)
            echo ""
            echo "[⚠️주의] 추가된 iptables 규칙은 재부팅 시 사라질 수 있습니다."
            echo "규칙 유지를 위해 시스템에 맞는 저장 명령어를 실행해야 합니다 (예: iptables-save > /etc/sysconfig/iptables)."
        else
            echo "[취소] 포트 차단 작업을 취소합니다."
        fi
        
        # 5. 추가 진행 여부 확인
        while true; do
            echo -e "\n추가로 포트를 확인/차단하시겠습니까? (y/n)"
            read -r NEXT_ACTION
            if [[ "$NEXT_ACTION" =~ ^[yY]$ ]]; then
                # 추가 작업을 위해 닫는 작업 루프만 반복
                break
            elif [[ "$NEXT_ACTION" =~ ^[nN]$ ]]; then
                echo -e "\n[종료] 포트 확인 도우미를 종료합니다. 감사합니다."
                return 1 # 전체 스크립트 종료
            else
                echo "[오류] 'y' 또는 'n'만 입력해 주세요."
            fi
        done
    done
}

# 스크립트 실행
check_and_close_ports
