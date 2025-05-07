#!/bin/bash

LOG_PATH="$HOME/cert_check/log"
TMP_PATH="$HOME/cert_check/tmp"

DOMAINS_FILE="$HOME/cert_check/domain-list.txt"
REPORT="$TMP_PATH/domain_report.txt"
LOG="$LOG_PATH/domain_check.log"
EMAIL="oci@superlearn.ing"

# 폴더가 존재하지 않으면 생성
if [ ! -d "$LOG_PATH" ]; then
    mkdir -p "$LOG_PATH"
    echo "폴더를 생성했습니다: $LOG_PATH"
else
    echo "폴더가 이미 존재합니다: $LOG_PATH"
fi

if [ ! -d "$TMP_PATH" ]; then
    mkdir -p "$TMP_PATH"
    echo "폴더를 생성했습니다: $TMP_PATH"
else
    echo "폴더가 이미 존재합니다: $TMP_PATH"
fi

check_health() {
  local domain=$1
  if curl -s --head "https://$domain" | grep -q "200 OK"; then
    echo "OK"
  else
    echo "DOWN"
    echo "[$(date)] Health check failed for $domain" >> "$LOG"
  fi
}

check_ssl_expiry() {
  local domain=$1
  expiry_date=$(openssl s_client -servername "$domain" -connect "$domain:443" < /dev/null 2>/dev/null | \
    openssl x509 -noout -enddate | cut -d= -f2)

  if [ -z "$expiry_date" ]; then
    echo "SSL 정보 없음"
    echo "[$(date)] SSL check failed for $domain" >> "$LOG"
    return
  fi

  expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null)
  if [ -z "$expiry_epoch" ]; then
    echo "SSL 날짜 파싱 오류"
    echo "[$(date)] Failed to parse SSL date for $domain: $expiry_date" >> "$LOG"
    return
  fi

  current_epoch=$(date +%s)
  days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
  echo "$expiry_date ($days_left일 남음)"
}

check_domain_expiry() {
  local domain=$1
  expiry_date=$(whois "$domain" | grep -iE 'Expiration Date|Registry Expiry Date|Expires on' | head -n1 | awk -F: '{print $2}' | sed 's/^ *//')

  if [ -z "$expiry_date" ]; then
    echo "도메인 만료일 정보 없음"
    echo "[$(date)] Whois 만료일 조회 실패: $domain" >> "$LOG"
    return
  fi

  expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null)
  if [ -z "$expiry_epoch" ]; then
    echo "WHOIS 날짜 파싱 오류"
    echo "[$(date)] Whois 날짜 파싱 실패: $domain - $expiry_date" >> "$LOG"
    return
  fi

  current_epoch=$(date +%s)
  days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
  echo "$expiry_date ($days_left일 남음)"
}
# 초기화
echo "==============================" >> "$LOG"
echo "스크립트 실행: $(date)" >> "$LOG"

echo "보고서 생성 시간: $(date '+%Y-%m-%d %H:%M:%S %Z')" > "$REPORT"
echo "" >> "$REPORT"

while read -r domain; do
  [ -z "$domain" ] && continue

  echo "도메인 처리 중: $domain" >> "$LOG"

  health=$(check_health "$domain")
  ssl=$(check_ssl_expiry "$domain")
  domain_expiry=$(check_domain_expiry "$domain")

  printf "%-25s %-10s SSL: %-35s 도메인 만료일: %s\n" "$domain" "$health" "$ssl" "$domain_expiry" >> "$REPORT"
done < "$DOMAINS_FILE"

# 이메일 전송
(
  echo "Subject: 도메인 상태 및 만료일 보고서"
  echo "To: $EMAIL"
  echo "Content-Type: text/plain; charset=UTF-8"
  echo ""
  cat "$REPORT"
) | /usr/sbin/sendmail -t

echo "이메일 전송 완료: $(date)" >> "$LOG"