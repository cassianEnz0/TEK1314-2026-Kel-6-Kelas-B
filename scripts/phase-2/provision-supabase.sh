#!/bin/bash
exec >/var/log/prov2.log 2>&1
set -x
echo "[prov2] START $(date)"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y docker.io docker-compose-v2 git postgresql-client-16 ufw fail2ban auditd jq curl openssl net-tools
systemctl enable --now docker
usermod -aG docker user
for i in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 2; done
docker --version; docker compose version
cd /opt
[ -d supabase ] || git clone --depth 1 https://github.com/supabase/supabase
cd /opt/supabase/docker
[ -f .env ] || cp .env.example .env
docker compose pull
docker compose up -d
echo "[prov2] menunggu db sehat"
for i in $(seq 1 90); do
  docker compose exec -T db pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 5
done
sleep 8
docker compose exec -T db psql -U postgres -d postgres <<'SQL'
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid primary key default gen_random_uuid(),
  nama text, email text, no_hp text
);
CREATE TABLE IF NOT EXISTS public.sensor_readings (
  id bigserial primary key, owner_id uuid,
  suhu numeric, kelembapan numeric, ts timestamptz default now()
);
TRUNCATE public.profiles;
TRUNCATE public.sensor_readings;
INSERT INTO public.profiles (nama,email,no_hp) VALUES
 ('Mitra Admin','admin@sahirafarm.id','0812-0000-0001'),
 ('Operator Kebun','operator@sahirafarm.id','0812-0000-0002'),
 ('Teknisi IoT','teknisi@sahirafarm.id','0812-0000-0003');
INSERT INTO public.sensor_readings (owner_id,suhu,kelembapan)
 SELECT gen_random_uuid(), round((25+random()*5)::numeric,2), round((60+random()*20)::numeric,2)
 FROM generate_series(1,10);
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT ON public.sensor_readings, public.profiles TO anon, authenticated;
NOTIFY pgrst, 'reload schema';
SQL
docker compose restart rest
echo "[prov2] DONE $(date)"
touch /opt/prov2.done
