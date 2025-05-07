#!/bin/bash

# 인수: 도메인명
domain=$1

# OCI Load Balancer OCID (환경에 맞게 수정)
LB_OCID="ocid1.loadbalancer.oc1..exampleuniqueID"

# OCI Load Balancer Listener 이름 (환경에 맞게 수정)
LISTENER_NAME="listener_https"

# 인증서 이름 (LB 내에서 식별용)
CERT_NAME="${domain}_cert"

# 인증서 파일 경로 (certbot 발급 경로)
CERT_FILE="/etc/letsencrypt/live/${domain}/fullchain.pem"
KEY_FILE="/etc/letsencrypt/live/${domain}/privkey.pem"

if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
  echo "ERROR: 인증서 파일이 존재하지 않습니다: $CERT_FILE 또는 $KEY_FILE"
  exit 1
fi

# 인증서 내용 읽기 (개행 제거)
CERT_CONTENT=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' "$CERT_FILE")
KEY_CONTENT=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' "$KEY_FILE")

# 기존 인증서 OCID 조회 (있으면 update, 없으면 create)
EXISTING_CERT_OCID=$(oci lb certificate list --load-balancer-id "$LB_OCID" --query "data[?name=='$CERT_NAME'].id | [0]" --raw-output)

if [ -z "$EXISTING_CERT_OCID" ] || [ "$EXISTING_CERT_OCID" == "null" ]; then
  echo "[$(date)] 인증서 생성 중: $CERT_NAME"
  oci lb certificate create --load-balancer-id "$LB_OCID" --name "$CERT_NAME" \
    --certificate-file "$CERT_FILE" --private-key-file "$KEY_FILE"
else
  echo "[$(date)] 인증서 업데이트 중: $CERT_NAME"
  oci lb certificate update --load-balancer-id "$LB_OCID" --certificate-name "$CERT_NAME" \
    --certificate-file "$CERT_FILE" --private-key-file "$KEY_FILE" --force
fi

# (선택) 리스너에 인증서 적용 확인 및 필요시 리스너 업데이트
# OCI LB 리스너가 인증서 이름을 참조하도록 설정되어 있어야 함

echo "[$(date)] OCI LB 인증서 설치 완료: $domain"