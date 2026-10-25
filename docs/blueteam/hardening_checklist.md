# Hardening Checklist - Target Node Replika (Self-Hosted Supabase)

**Mata Kuliah:** TEK1314 - Keamanan Siber
**Kelompok:** 6 Kelas B, Tim Blue Team
**Standar:** Panduan PBL Bagian VIII (min. 8 kontrol, min. 2 per kategori A/B/C)
**Path repo:** `docs/blueteam/hardening_checklist.md`
**Target:** 172.16.6.10 (Ubuntu 24.04 + Supabase self-hosted)

---

## Cara pakai dokumen ini

- Status: `Selesai` / `Sebagian` / `Belum`.
- Setiap kontrol wajib punya bukti before/after (screenshot config atau output
  command), disimpan di `evidence/`.
- Hardening hanya di satu layer (misal cuma SSH) tidak memenuhi standar, harus
  mencakup ketiga kategori.
- Detail perintah tiap kontrol ada di `hardening_plan.md`.

---

## Kategori A - Access dan Authentication (min. 2 kontrol)

| # | Kontrol | Target komponen | Bukti wajib | Status |
|---|---|---|---|---|
| A1 | Nonaktifkan login root via SSH (`PermitRootLogin no`) | OS | screenshot `sshd_config` before/after + `ssh root@target` gagal | Selesai |
| A2 | SSH key-based auth, disable password (`PasswordAuthentication no`) | OS | screenshot config before/after + login password ditolak | Selesai |
| A3 | fail2ban rate-limit login SSH | OS | `fail2ban-client status sshd` + log IP ter-ban | Selesai |
| A4 | Ganti kredensial default dashboard Studio | Supabase Studio | `.env` before/after + login lama gagal (401) | Selesai |

> Untuk rate limit login GoTrue (Auth), fail2ban bawaan tidak cukup karena jail
> bawaannya hanya `sshd`. Jalur yang benar adalah rate limiting di sisi gateway
> (Envoy), jadi itu pekerjaan tambahan, bukan otomatis dari fail2ban.

---

## Kategori B - Service dan Attack Surface (min. 2 kontrol)

| # | Kontrol | Target komponen | Bukti wajib | Status |
|---|---|---|---|---|
| B1 | Firewall UFW whitelist: hanya gateway 8000 + SSH dari segmen mgmt; tutup selebihnya | OS | output nmap before vs after | Selesai |
| B2 | Pooler/DB tidak bind ke 0.0.0.0, hanya loopback (`127.0.0.1`) | Supavisor/Postgres | `ss -tlnp` before/after + nmap 5432/6543 filtered | Selesai |
| B3 | Update dan patch image Docker + paket OS | OS + containers | versi before/after (`docker images`, `apt list --upgradable`) | Sebagian |
| B4 | Matikan service tak dipakai (realtime, functions) | Docker Compose | `docker compose ps` before/after | Selesai |

> B1 dan B2 bersama adalah bukti utama "nmap before vs after". Ingat jebakan:
> UFW saja tidak menutup port yang dipublish Docker; B2 yang benar-benar menutup
> 5432/6543. Lihat bukti di `evidence/s1-nmap-before.txt` dan `s1-nmap-after.txt`.

---

## Kategori C - Data dan Application (min. 2 kontrol)

| # | Kontrol | Target komponen | Bukti wajib | Status |
|---|---|---|---|---|
| C1 | Aktifkan dan perketat Row Level Security pada tabel sensor dan user | PostgreSQL / PostgREST | policy SQL + test: query anon ditolak (before bocor, after 401) | Selesai |
| C2 | Rotasi secret, tidak ada kredensial default/hardcoded | Semua service (`.env`) | `.env` before/after (nilai di-mask) + key lama invalid | Sebagian |
| C3 | Least privilege user DB (role khusus, bukan superuser) | PostgreSQL | `\du` / GRANT before/after | Sebagian |
| C4 | Logging aktivitas mencurigakan diteruskan ke Security Onion | Postgres + gateway | config logging + contoh log akses gagal | Sebagian |

> C1 (RLS) adalah kontrol paling krusial untuk Supabase. Tanpa RLS, PostgREST
> mengekspos seluruh tabel ke pemegang anon key. Ini target langsung skenario
> Red Team (lihat `attack_plan.md` S2).

---

## Rekap pemenuhan standar Bagian VIII

Minimal 8 kontrol, tersebar minimal 2 per kategori. Set yang dikerjakan:

- A: A1, A2, A3, A4 (selesai)
- B: B1, B2, B4 (selesai), B3 (sebagian)
- C: C1 (selesai), C2, C3, C4 (sebagian)

Total 11 kontrol, ketiga kategori terpenuhi.

> Pada tahap ini yang dinilai adalah kejelasan rencana dan progres hardening.
> Status "Sebagian" dengan bukti parsial lebih jujur daripada klaim "Selesai"
> tanpa bukti. Yang masih "Sebagian" (rotasi secret penuh, role DB, logging ke
> SO) dilanjutkan pada tahap eksekusi berikutnya.
