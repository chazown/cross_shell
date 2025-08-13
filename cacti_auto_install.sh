#!/bin/bash

# 변수 정의
DBNAME="cacti"
DBUSER="cacti"
DBPASS="asd123!@"
DBHOST="localhost"
CONFIG_FILE="/usr/share/cacti/include/config.php"
CONFIG_DIST="/usr/share/cacti/include/config.php.dist"
CACTI_SQL_SRC="/usr/share/doc/cacti/cacti.sql"
CACTI_SQL_DST="/usr/share/cacti/cacti.sql"
TIMEZONE_SQL_URL="https://raw.githubusercontent.com/google/mysql/master/scripts/mysql_test_data_timezone.sql"
PHP_INI="/etc/php.ini"

echo "[*] Cacti 자동 설치 및 설정 스크립트 시작"

# 1. DB 존재 여부 확인
echo "[*] 데이터베이스 '${DBNAME}' 존재 여부 확인..."
if mysql -u root -e "USE ${DBNAME};" 2>/dev/null; then
    echo "[*] 데이터베이스 '${DBNAME}'는 이미 존재합니다. 생성 생략."
else
    echo "[+] 데이터베이스 '${DBNAME}' 생성 중..."
    mysql -u root -e "CREATE DATABASE ${DBNAME};"
fi

# 2. 사용자 존재 여부 확인
echo "[*] 사용자 '${DBUSER}' 존재 여부 확인..."
if mysql -u root -e "SELECT User FROM mysql.user WHERE User='${DBUSER}';" | grep -q "${DBUSER}"; then
    echo "[*] 사용자 '${DBUSER}'는 이미 존재합니다. 생성 생략."
else
    echo "[+] 사용자 '${DBUSER}' 생성 및 권한 부여 중..."
    mysql -u root -e "CREATE USER '${DBUSER}'@'${DBHOST}' IDENTIFIED BY '${DBPASS}';"
    mysql -u root -e "GRANT ALL PRIVILEGES ON ${DBNAME}.* TO '${DBUSER}'@'${DBHOST}';"
    mysql -u root -e "FLUSH PRIVILEGES;"
fi

# 3. 테이블 존재 여부 확인 및 cacti.sql 임포트
echo "[*] '${DBNAME}' 테이블 존재 여부 확인..."
if ! mysql -u root -D ${DBNAME} -e "SHOW TABLES;" | grep -q .; then
    if [ -f "$CACTI_SQL_SRC" ]; then
        echo "[+] '$CACTI_SQL_SRC' → '$CACTI_SQL_DST' 복사"
        cp "$CACTI_SQL_SRC" "$CACTI_SQL_DST"
        echo "[+] '${DBNAME}' DB에 cacti.sql 임포트 중..."
        mysql -u root ${DBNAME} < "$CACTI_SQL_DST"
    else
        echo "[!] '$CACTI_SQL_SRC' 파일이 없습니다. 설치가 잘못되었을 수 있습니다."
        exit 1
    fi
else
    echo "[*] '${DBNAME}' DB에는 이미 테이블이 존재합니다. 임포트 생략."
fi

# 4. 타임존 데이터 임포트
echo "[*] 타임존 데이터 존재 여부 확인..."
if mysql -u root -D mysql -e "SELECT * FROM time_zone_name LIMIT 1;" 2>/dev/null | grep -q .; then
    echo "[*] 타임존 데이터가 이미 존재합니다. 임포트 생략."
else
    echo "[+] 타임존 데이터 다운로드 및 임포트 중..."
    wget -q ${TIMEZONE_SQL_URL} -O /tmp/mysql_test_data_timezone.sql
    mysql -u root mysql < /tmp/mysql_test_data_timezone.sql
fi

# 5. config.php 설정
echo "[*] Cacti config.php 존재 여부 확인..."
if [ -f "$CONFIG_FILE" ]; then
    echo "[*] config.php는 이미 존재합니다. 복사 생략."
else
    if [ -f "$CONFIG_DIST" ]; then
        echo "[+] config.php.dist 복사 중..."
        cp "$CONFIG_DIST" "$CONFIG_FILE"
    else
        echo "[!] config.php.dist 파일이 없습니다. 복사 실패."
        exit 1
    fi
fi

echo "[+] config.php DB 설정 수정 중..."
sed -i "s|\$database_type = .*|\$database_type = 'mysql';|" ${CONFIG_FILE}
sed -i "s|\$database_default = .*|\$database_default = '${DBNAME}';|" ${CONFIG_FILE}
sed -i "s|\$database_hostname = .*|\$database_hostname = '${DBHOST}';|" ${CONFIG_FILE}
sed -i "s|\$database_username = .*|\$database_username = '${DBUSER}';|" ${CONFIG_FILE}
sed -i "s|\$database_password = .*|\$database_password = '${DBPASS}';|" ${CONFIG_FILE}

# 6. PHP 타임존 설정
echo "[*] PHP timezone 설정 확인..."
if grep -q "^date.timezone = Asia/Seoul" ${PHP_INI}; then
    echo "[*] PHP timezone은 이미 Asia/Seoul로 설정되어 있습니다."
else
    echo "[+] PHP timezone을 Asia/Seoul로 설정 중..."
    sed -i 's|^;date.timezone =.*|date.timezone = Asia/Seoul|' ${PHP_INI}
fi

echo "[*] 완료되었습니다. 필요 시 httpd, mariadb 서비스 재시작 하세요."
