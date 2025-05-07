#!/bin/bash

DOMAIN=$CERTBOT_DOMAIN

DOMAIN_LIST="$HOME/cert_check/domain-list.txt"

ZONE_OCID=$(awk -v domain="$DOMAIN" '$1 == domain {print $3}' "$DOMAIN_LIST")

if [ -z "$ZONE_OCID" ]; then
  echo "ERROR: ZONE_OCID가 설정되어 있지 않습니다: $DOMAIN"
  exit 1
fi

RECORD_NAME="_acme-challenge.${DOMAIN}"

oci dns record zone rrset patch --zone-name-or-id "$ZONE_OCID" \
  --domain "$RECORD_NAME" --rtype TXT --items '[]' --if-match '*'