#!/bin/bash
exec >/var/log/harden.log 2>&1
set -x
cd /opt/supabase/docker || exit 1
DC="docker compose"

echo "===== C1 RLS + C3 least-privilege (tutup S2) ====="
$DC exec -T db psql -U postgres -d postgres <<'SQL'
ALTER TABLE public.sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sensor_readings FORCE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "read own readings" ON public.sensor_readings;
CREATE POLICY "read own readings" ON public.sensor_readings
  FOR SELECT TO authenticated USING (owner_id = auth.uid());
DROP POLICY IF EXISTS "read own profile" ON public.profiles;
CREATE POLICY "read own profile" ON public.profiles
  FOR SELECT TO authenticated USING (id = auth.uid());
REVOKE ALL ON public.sensor_readings FROM anon;
REVOKE ALL ON public.profiles FROM anon;
NOTIFY pgrst, 'reload schema';
SQL
$DC restart rest

echo "===== A4 ganti password default dashboard (tutup S3 dashboard) ====="
NEWDASH=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | cut -c1-20)
sed -i "s|^DASHBOARD_PASSWORD=.*|DASHBOARD_PASSWORD=${NEWDASH}|" .env
echo "DASHBOARD_USERNAME=supabase"  > /root/creds-hardened.txt
echo "DASHBOARD_PASSWORD=${NEWDASH}" >> /root/creds-hardened.txt

echo "===== B2 ikat pooler ke loopback (tutup 5432/6543 dari jaringan) ====="
cp docker-compose.yml docker-compose.yml.bak
sed -i 's#- ${POSTGRES_PORT}:5432#- 127.0.0.1:${POSTGRES_PORT}:5432#' docker-compose.yml
sed -i 's#- ${POOLER_PROXY_PORT_TRANSACTION}:6543#- 127.0.0.1:${POOLER_PROXY_PORT_TRANSACTION}:6543#' docker-compose.yml

echo "===== terapkan perubahan compose + .env ====="
$DC up -d

echo "===== B4 matikan service tak dipakai ====="
$DC stop realtime functions 2>/dev/null || true

echo "===== B1 firewall UFW (hanya 8000 + SSH dari subnet) ====="
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow from 192.168.6.0/24 to any port 22 proto tcp
ufw allow from 172.16.6.1 to any port 22 proto tcp
ufw allow 8000/tcp
ufw --force enable

echo "===== A1/A2 SSH key-only, root off ====="
cat >/etc/ssh/sshd_config.d/99-hardening.conf <<'SSHC'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
AllowUsers user
SSHC
systemctl restart ssh.socket 2>/dev/null; systemctl restart ssh 2>/dev/null

echo "===== A3 fail2ban (rate limit SSH) ====="
cat >/etc/fail2ban/jail.d/sshd.local <<'F2B'
[sshd]
enabled = true
port = 22
backend = systemd
maxretry = 4
findtime = 600
bantime = 3600
F2B
systemctl enable --now fail2ban
systemctl restart fail2ban

echo "[harden] DONE $(date)"
touch /opt/harden.done
