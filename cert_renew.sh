#!/bin/bash

LOG_PATH="$HOME/cert_check/log"
TMP_PATH="$HOME/cert_check/tmp"
DOMAIN_LIST="$HOME/cert_check/domain-list.txt"
LOG="$LOG_PATH/cert_renew.log"
EMAIL="cert@superlearn.ing"

mkdir -p "$LOG_PATH" "$TMP_PATH"

get_formatted_date() {
  LC_ALL=ko_KR.UTF-8 date '+%Y-%m-%d %H:%M:%S'
}

log() {
  echo "[$(get_formatted_date)] $1" >> "$LOG"
}

check_ssl_expiry() {
  local domain=$1
  expiry_date=$(openssl s_client -servername "$domain" -connect "$domain:443" < /dev/null 2>/dev/null | \
    openssl x509 -noout -enddate | cut -d= -f2)

  if [ -z "$expiry_date" ]; then
    echo ""
    return
  fi

  expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null)
  current_epoch=$(date +%s)
  days_left=$(( (expiry_epoch - current_epoch) / 86400 ))

  echo "$days_left"
}

install_cert_oci_lb() {
  local domain=$1
  ./hooks/install_cert_oci_lb.sh "$domain"
}

install_cert_instance_nginx() {
  local domain=$1
  log "[$domain] 인스턴스 Nginx 인증서 설치 시작"
  # 예시 경로, 실제 환경에 맞게 수정 필요
  local cert_src="/etc/letsencrypt/live/$domain/fullchain.pem"
  local key_src="/etc/letsencrypt/live/$domain/privkey.pem"
  local cert_dst="/etc/nginx/certs/$domain.crt"
  local key_dst="/etc/nginx/certs/$domain.key"

  cp "$cert_src" "$cert_dst"
  cp "$key_src" "$key_dst"
  systemctl reload nginx
  log "[$domain] 인스턴스 Nginx 인증서 설치 완료"
}

renew_cert() {
  local domain=$1
  local install_type=$2

  log "[$domain] 인증서 갱신 시작"

  certbot certonly --manual --preferred-challenges dns \
    --manual-auth-hook ./hooks/auth-hook.sh \
    --manual-cleanup-hook ./hooks/cleanup-hook.sh \
    -d "$domain" --non-interactive --agree-tos --email "$EMAIL"

  if [ $? -eq 0 ]; then
    log "[$domain] 인증서 갱신 성공"
    case "$install_type" in
      oci_lb)
        install_cert_oci_lb "$domain"
        ;;
      oci_instance_nginx)
        install_cert_instance_nginx "$domain"
        ;;
      *)
        log "[$domain] 알 수 없는 설치 유형: $install_type"
        ;;
    esac
  else
    log "[$domain] 인증서 갱신 실패"
  fi
}

while read -r line; do
  domain=$(echo "$line" | awk '{print $1}')
  install_type=$(echo "$line" | awk '{print $2}')
  [ -z "$domain" ] && continue

  days_left=$(check_ssl_expiry "$domain")

  if [ -z "$days_left" ] || [ "$days_left" -le 30 ]; then
    renew_cert "$domain" "$install_type"
  else
    log "[$domain] 인증서 만료 $days_left일 남음, 갱신 불필요"
  fi
done < "$DOMAIN_LIST"