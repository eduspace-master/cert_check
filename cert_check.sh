#!/bin/bash

LOG_PATH="$HOME/cert_check/log"
TMP_PATH="$HOME/cert_check/tmp"

DOMAINS_FILE="$HOME/cert_check/domain-list.txt"
REPORT="$TMP_PATH/domain_report.txt"
LOG="$LOG_PATH/domain_check.log"
EMAIL="oci@superlearn.ing"

# 날짜 형식 함수 (모든 날짜 형식 통일)
get_formatted_date() {
  LC_ALL=ko_KR.UTF-8 date "$@" '+%Y-%m-%d %H:%M %a'
}

# 폴더가 존재하지 않으면 생성
if [ ! -d "$LOG_PATH" ]; then
    mkdir -p "$LOG_PATH"
    echo "폴더를 생성했습니다: $LOG_PATH"
fi

if [ ! -d "$TMP_PATH" ]; then
    mkdir -p "$TMP_PATH"
    echo "폴더를 생성했습니다: $TMP_PATH"
fi

check_ssl_expiry() {
  local domain=$1
  # 인증서 만료일 확인
  expiry_date=$(openssl s_client -servername "$domain" -connect "$domain:443" < /dev/null 2>/dev/null | \
    openssl x509 -noout -enddate | cut -d= -f2)

  if [ -z "$expiry_date" ]; then
    echo "SSL 정보 없음"
    echo "[$(get_formatted_date)] SSL check failed for $domain" >> "$LOG"
    return
  fi

  # SAN 필드에서 와일드카드 인증서 여부 확인
  san=$(openssl s_client -servername "$domain" -connect "$domain:443" < /dev/null 2>/dev/null | \
    openssl x509 -noout -text | grep -A1 "Subject Alternative Name")

  if [[ "$san" == *"DNS:*.${domain}"* ]]; then
    wildcard_status="와일드카드 인증서"
  else
    wildcard_status="일반 인증서"
  fi

  expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null)
  if [ -z "$expiry_epoch" ]; then
    echo "SSL 날짜 파싱 오류"
    echo "[$(get_formatted_date)] Failed to parse SSL date for $domain: $expiry_date" >> "$LOG"
    return
  fi

  current_epoch=$(date +%s)
  days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
  
  # 날짜 형식 변환 (GMT -> KST, 요일 추가)
  expiry_kst=$(get_formatted_date -d "$expiry_date")
  
  # 반환 형식 변경 - 각 필드를 탭으로 구분해서 후처리가 쉽도록 함
  echo -e "$expiry_kst\t$days_left\t$wildcard_status"
}

# 초기화
echo "==============================" >> "$LOG"
echo "스크립트 실행: $(get_formatted_date)" >> "$LOG"

# 보고서 파일 초기화
> "$REPORT"

# 이메일에 사용할 보고서 헤더 작성
report_date=$(get_formatted_date)
echo "보고서 생성 시간: $report_date" > "$REPORT"
echo "" >> "$REPORT"
echo "도메인명                SSL 만료일                남은 일수       인증서 유형" >> "$REPORT"
echo "-------------------------------------------------------------" >> "$REPORT"

# 각 도메인 처리
while read -r domain; do
  [ -z "$domain" ] && continue

  echo "도메인 처리 중: $domain" >> "$LOG"

  ssl_info=$(check_ssl_expiry "$domain")
  
  if [[ "$ssl_info" == "SSL 정보 없음" || "$ssl_info" == "SSL 날짜 파싱 오류" ]]; then
    printf "%-25s %-25s\n" "$domain" "$ssl_info" >> "$REPORT"
  else
    # 탭으로 구분된 필드를 읽음
    ssl_date=$(echo "$ssl_info" | cut -f1)
    days_left=$(echo "$ssl_info" | cut -f2)
    wildcard_status=$(echo "$ssl_info" | cut -f3-)
    
    # 출력 형식 맞추기
    printf "%-25s %-25s %-15s %s\n" "$domain" "$ssl_date" "$days_left일 남음" "$wildcard_status" >> "$REPORT"
  fi
done < "$DOMAINS_FILE"

# 이메일 전송
(
  # 날짜 형식 지정
  today=$(get_formatted_date)
  
  echo "Subject: [인프라] $today 웹사이트 인증서 상태 보고서"
  echo "To: $EMAIL"
  echo "Content-Type: text/plain; charset=UTF-8"
  echo ""
  cat "$REPORT"
) | /usr/sbin/sendmail -t

echo "이메일 전송 완료: $(get_formatted_date)" >> "$LOG"
echo "로그 파일 위치: $LOG"