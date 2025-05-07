#!/bin/bash

DOMAINS_FILE="~/cert/domain-list.txt"
REPORT="~/cert/tmp/domain_report.txt"
LOG="~/cert/log/domain_check.log"
EMAIL="oci@superlearn.ing"

check_health() {
  local domain=$1
  if curl -s --head "https://$domain" | grep -q "200 OK"; then
    echo "OK"
  else
    echo "DOWN"
    echo "[(date)] Health check failed for $domain" >> "LOG"
  fi
}

check_ssl_expiry() {
  local domain=$1
  expiry_date=(openssl s_client -servername "$domain" -connect "domain:443" < /dev/null 2>/dev/null | \
    openssl x509 -noout -enddate | cut -d= -f2)

  if [ -z "$expiry_date" ]; then
    echo "SSL 정보 없음"
    echo "[(date)] SSL check failed for $domain" >> "LOG"
    return
  fi

  expiry_epoch=(date -d "expiry_date" +%s 2>/dev/null)
  if [ -z "$expiry_epoch" ]; then
    echo "SSL 날짜 파싱 오류"
    echo "[(date)] Failed to parse SSL date for $domain: $expiry_date" >> "LOG"
    return
  fi

  current_epoch=$(date +%s)
  days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
  echo "expiry_date ({days_left}일 남음)"
}

check_domain_expiry() {
  local domain=$1
  expiry_date=(whois "$domain" | grep -iE 'Expiration Date|Registry Expiry Date|Expires on' | head -n1 | awk -F: '{print 2}' | sed 's/^ *//')

  if [ -z "$expiry_date" ]; then
    echo "도메인 만료일 정보 없음"
    echo "[(date)] Whois 만료일 조회 실패: $domain" >> "LOG"
    return
  fi
