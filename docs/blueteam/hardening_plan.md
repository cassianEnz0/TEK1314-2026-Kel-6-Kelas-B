# Hardening Plan Fase 2 - Blue Team (Target Node Replika Self-Hosted Supabase)

**Mata Kuliah:** TEK1314 - Keamanan Siber
**Kelompok:** 6 Kelas B, Tim Blue Team
**Dokumen:** rencana teknis hardening, pendamping `hardening_checklist.md`
**Path repo:** `docs/blueteam/hardening_plan.md`
**Acuan:** Panduan PBL Bagian VIII dan Bagian X (Purple Team Loop)

> Seluruh perintah dijalankan hanya di Target Node replika (172.16.6.10), bukan di
> Supabase Cloud asli. Dokumen ini mencatat hardening yang benar-benar diterapkan
> plus hasil before/after yang sudah diverifikasi (folder `evidence/`).

---

## 1. Tujuan dan prinsip

Mengurangi attack surface dan menutup celah yang diserang Red Team (recon, data
exfiltration lewat REST, brute force).

1. Satu pintu masuk. Hanya gateway Envoy (8000) yang boleh diakses dari jaringan lab.
2. Default deny. Firewall menolak semua, lalu hanya membuka yang perlu.
3. Least privilege. Tiap komponen punya hak seminimnya.
4. Semua tercatat. Aktivitas mencurigakan terekam dan bisa dibaca Security Onion.
5. Bukti before/after. Tiap kontrol diukur sebelum dan sesudah.

## 2. Lingkungan

Topologi tiga segmen (lihat [ip_plan](../design/ip_plan.md)): Attacker Kali
10.6.6.10, Target 172.16.6.10, Monitoring Security Onion 192.168.6.10. Target
menjalankan stack resmi supabase/docker di Ubuntu 24.04 + Docker.

Port terekspos pada kondisi default (rapuh): 8000 (Envoy), 5432 dan 6543
(Supavisor pooler), 22 (SSH). PostgREST (3000), GoTrue (9999), dan Studio di balik
Envoy.

> Jebakan penting: port yang dipublish Docker lewat blok `ports:` menulis aturan
> iptables sendiri dan menembus UFW. Jadi UFW saja tidak cukup untuk menutup port
> container. Yang benar-benar menutupnya adalah mengikat port ke `127.0.0.1` atau
> menghapus `ports:` (kontrol B2). Buktikan selalu lewat nmap dari Kali, bukan
> sekadar `ufw status`.

## 3. Urutan eksekusi (aman dari lock-out)

| Urutan | Langkah | Alasan |
|---|---|---|
| 0 | Snapshot VM + simpan `docker-compose.yml`, `.env` asli | Rollback dan bukti before |
| 1 | Baseline: `nmap`, `ss -tlnp`, `docker compose ps` | Bukti before |
| 2 | C1 + C3 RLS dan role DB | Menutup S2 |
| 3 | A4 ganti kredensial default dashboard | Menutup S3 bagian dashboard |
| 4 | B2 + B4 ikat port internal ke loopback dan matikan service tak dipakai | Kurangi surface |
| 5 | B1 UFW | Setelah port internal beres |
| 6 | A2 lalu A1 lalu A3 (kunci SSH diuji dulu, baru password dimatikan) | Hindari terkunci |
| 7 | C4 logging + forward ke Security Onion | Siap deteksi |
| 8 | Re-scan `nmap` after, simpan bukti | Bukti after |

## 4. Kontrol hardening yang dijalankan

Dijalankan sebagai root di Target Node, sebagian di `/opt/supabase/docker`. `DC`
berarti `docker compose`. Skrip lengkap: `scripts/phase-2/harden-supabase.sh`.

### Kategori C - Data dan Aplikasi

**C1 - Row Level Security (menutup S2, paling krusial)**

```sql
ALTER TABLE public.sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sensor_readings FORCE  ROW LEVEL SECURITY;
ALTER TABLE public.profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles        FORCE  ROW LEVEL SECURITY;

CREATE POLICY "read own readings" ON public.sensor_readings
  FOR SELECT TO authenticated USING (owner_id = auth.uid());
CREATE POLICY "read own profile" ON public.profiles
  FOR SELECT TO authenticated USING (id = auth.uid());

REVOKE ALL ON public.sensor_readings FROM anon;
REVOKE ALL ON public.profiles        FROM anon;
NOTIFY pgrst, 'reload schema';
```

Lalu `DC restart rest`. Efek terbukti: anon key yang tadi menumpahkan data kini
dibalas HTTP 401 permission denied (lihat `evidence/s2-exfil-after.json`).

**C3 - Least privilege DB (langkah lanjutan).** Role khusus aplikasi tanpa
superuser. Role bawaan Supabase (`anon`, `authenticated`, `authenticator`,
`service_role`) tidak dihapus karena dipakai PostgREST dan GoTrue, hanya hak-nya
dibatasi.

```sql
CREATE ROLE app_rest NOINHERIT LOGIN PASSWORD '<acak>';
GRANT USAGE ON SCHEMA public TO app_rest;
GRANT SELECT, INSERT ON public.sensor_readings TO app_rest;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
```

**C2 - Rotasi secret (langkah lanjutan).** Ganti `POSTGRES_PASSWORD`,
`JWT_SECRET`, lalu generate ulang `ANON_KEY` dan `SERVICE_ROLE_KEY` dari
`JWT_SECRET` baru (keduanya JWT yang ditandatangani secret itu, jadi key lama
otomatis invalid). Pada implementasi ini yang sudah dijalankan baru penggantian
password dashboard (A4); rotasi penuh didokumentasikan sebagai langkah lanjutan.

**C4 - Logging ke Security Onion.** Aktifkan log koneksi dan statement PostgreSQL,
pastikan access log gateway hidup, lalu teruskan log ke Monitoring Node.

```sql
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_statement = 'ddl';
SELECT pg_reload_conf();
```

### Kategori A - Access dan Authentication

**A4 - Ganti kredensial default dashboard (menutup S3 dashboard).**

```
NEWDASH=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | cut -c1-20)
sed -i "s|^DASHBOARD_PASSWORD=.*|DASHBOARD_PASSWORD=${NEWDASH}|" .env
DC up -d
```

Efek terbukti: login lama `supabase:this_password_is_insecure...` kini HTTP 401
(lihat `evidence/s3-brute-after.txt`).

**A1 dan A2 - SSH key-only, root off.** Isi `/etc/ssh/sshd_config.d/99-hardening.conf`:

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
AllowUsers user
```

**A3 - Rate limit SSH (fail2ban).** Isi `/etc/fail2ban/jail.d/sshd.local` (jail
`sshd`, port 22, ban 1 jam setelah 4 gagal), lalu `systemctl enable --now
fail2ban`. Catatan: fail2ban bawaan hanya punya jail `sshd`. Untuk rate limit
login GoTrue, ambil jalur di sisi gateway (rate limiting di Envoy), bukan fail2ban.

### Kategori B - Service dan Attack Surface

**B2 - Ikat pooler ke loopback (menutup 5432/6543 dari jaringan).** Di
`docker-compose.yml`:

```
# sebelum
- ${POSTGRES_PORT}:5432
- ${POOLER_PROXY_PORT_TRANSACTION}:6543
# sesudah
- 127.0.0.1:${POSTGRES_PORT}:5432
- 127.0.0.1:${POOLER_PROXY_PORT_TRANSACTION}:6543
```

Lalu `DC up -d`. Inilah kontrol yang benar-benar menutup 5432 dan 6543 dari
jaringan, bukan UFW.

**B4 - Matikan service tak dipakai.** `DC stop realtime functions`.

**B1 - Firewall UFW (bukti utama nmap before vs after).**

```
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow from 192.168.6.0/24 to any port 22 proto tcp
ufw allow 8000/tcp
ufw --force enable
```

SSH hanya dibuka dari segmen manajemen (192.168.6.0/24, tempat Security Onion),
gateway 8000 dibiarkan publik supaya tetap bisa diakses dari segmen Attacker.

## 5. Bukti before vs after (sudah diverifikasi dari Kali)

| Uji | Kondisi rapuh | Kondisi hardened | Bukti |
|---|---|---|---|
| nmap port terbuka | 22, 5432, 6543, 8000 | 22, 8000 (5432 dan 6543 filtered) | `evidence/s1-nmap-*.txt` |
| curl anon ke `/rest/v1/sensor_readings` | data tumpah (JSON penuh) | HTTP 401 permission denied | `evidence/s2-exfil-*.json` |
| curl anon ke `/rest/v1/profiles` | data pengguna bocor | HTTP 401 permission denied | `evidence/s2-exfil-*.json` |
| kredensial default dashboard | diterima (HTTP 307) | HTTP 401 | `evidence/s3-brute-*.txt` |

## 6. Pemetaan kontrol ke skenario Red Team

| Skenario | Celah | Kontrol penutup | Deteksi |
|---|---|---|---|
| S1 Recon | banyak port terbuka | B1, B2, B4 | alert port scan (Zeek/Suricata) |
| S2 Data exfiltration via REST | RLS mati, anon key baca semua | C1, C2, C3 | lonjakan request `/rest/v1/*`, 401 berulang |
| S3 Brute force / default cred | kredensial default, tanpa rate limit | A4, A3, A1, A2 | fail2ban ban, banyak 401 di `/auth/v1/token` |
| S4 (opsional) SYN flood | gateway tanpa proteksi | B1 + `tcp_syncookies=1` | anomali volume SYN |

## 7. Deteksi di Security Onion

Trafik segmen Attacker dan Target dimirror ke NIC monitor Security Onion (satu
arah, hanya dibaca), plus log Target diteruskan ke Monitoring Node. Alert yang
disiapkan: port scan, REST data dump, brute force login, SSH brute force, dan SYN
flood. Tiap alert dicatat statusnya (muncul atau tidak) untuk tahap verifikasi
Purple Team. Alert yang tidak muncul tetap temuan penting.

## 8. Alur demo (snapshot)

Dua snapshot pada VM target supaya kondisi bisa ditukar seketika saat live:

- Snapshot `rapuh`: RLS off, kredensial default, 5432/6543 terbuka.
- Snapshot `hardened`: RLS on, kredensial diganti, pooler di loopback, UFW aktif, SSH key-only, fail2ban.

Serang dari Kali pada `rapuh`, revert ke `hardened`, lalu ulangi serangan yang
sama dan tunjukkan kini gagal plus jejak deteksinya.

## 9. Risiko dan catatan

| Risiko | Mitigasi |
|---|---|
| Terkunci dari SSH | uji kunci sebelum menonaktifkan password; pakai snapshot |
| Docker menembus UFW | wajib B2 (loopback), verifikasi dengan nmap dari luar |
| Ganti JWT_SECRET membuat key lama invalid | generate ulang ANON_KEY dan SERVICE_ROLE_KEY, restart semua service |
| RLS terlalu ketat sampai app simulasi gagal | tes dengan akun authenticated sebelum dan sesudah policy |
| Secret ikut ter-commit | `.gitignore` untuk `.env`, mask screenshot |

---

*Status tiap kontrol dilaporkan di `hardening_checklist.md`.*
