#!/bin/bash

DOMAIN=$CERTBOT_DOMAIN
TOKEN_VALUE=$CERTBOT_VALIDATION

# domain-list.txt 경로
DOMAIN_LIST="$HOME/cert_check/domain-list.txt"

# 도메인에 맞는 ZONE_OCID 찾기
ZONE_OCID=$(awk -v domain="$DOMAIN" '$1 == domain {print $3}' "$DOMAIN_LIST")

if [ -z "$ZONE_OCID" ]; then
  echo "ERROR: ZONE_OCID가 설정되어 있지 않습니다: $DOMAIN"
  exit 1
fi

RECORD_NAME="_acme-challenge.${DOMAIN}"
RECORDS_JSON=$(jq -n --arg val "$TOKEN_VALUE" '[{ "rdata": $val, "ttl": 300 }]')

oci dns record zone rrset patch --zone-name-or-id "$ZONE_OCID" \
  --domain "$RECORD_NAME" --rtype TXT --items "$RECORDS_JSON" --if-match '*'

sleep 30