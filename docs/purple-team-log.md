# Purple Team Log (Bagian X)

**Mata Kuliah:** TEK1314 - Keamanan Siber, Kelompok 6 Kelas B
**Target:** replika self-hosted Supabase di 172.16.6.10 (lihat `presentation-minggu9/tech_stack_declaration.md`)

Setiap skenario Red Team (lihat `redteam/attack_plan.md`) melewati lima tahap:
Serang (baseline), Deteksi, Analisis, Respons (mitigasi Blue Team), Verifikasi.
Bukti before/after ada di `blueteam/evidence/`.

> Catatan tahap: untuk Minggu ke-9, yang dinilai adalah rencana. Loop tertutup ini
> dikerjakan lebih awal sebagai bahan Vulnerability Assessment Report Minggu ke-11.
> Tahap Deteksi (alert Security Onion) dilengkapi setelah sensor SO aktif memantau
> trafik segmen attacker dan target lewat mirror; sampai itu, deteksi dicatat dari
> log layanan di Target Node.

---

## S1 - Reconnaissance (nmap)

1. Serang (baseline): `nmap -Pn -sV` dari Kali (10.6.6.10) ke 172.16.6.10 memetakan
   port terbuka. Hasil: 22, 5432, 6543, 8000. Bukti: `blueteam/evidence/s1-nmap-before.txt`.
2. Deteksi: diharapkan alert port scan (Zeek/Suricata) di Security Onion saat banyak
   SYN ke banyak port dari satu IP. (Menunggu sensor SO aktif.)
3. Analisis: pooler Postgres (5432/6543) dan gateway terbuka ke jaringan karena
   publikasi port Docker default, tanpa firewall.
4. Respons (mitigasi): B2 ikat pooler ke loopback, B4 matikan service tak dipakai,
   B1 UFW hanya izinkan 8000 dan SSH dari segmen manajemen.
5. Verifikasi: nmap diulang, port terbuka tinggal 22 dan 8000; 5432 dan 6543 filtered.
   Bukti: `blueteam/evidence/s1-nmap-after.txt`. Loop tertutup.

## S2 - Data exfiltration via REST API

1. Serang (baseline): `curl` dengan anon key ke `/rest/v1/sensor_readings` dan
   `/rest/v1/profiles` menarik seluruh data tanpa otorisasi. Bukti: `blueteam/evidence/s2-exfil-before.json`.
2. Deteksi: diharapkan lonjakan request `/rest/v1/*` dengan `select=*` di log gateway,
   diteruskan ke Security Onion. (Menunggu forwarding log ke SO.)
3. Analisis: Row Level Security tidak aktif, sehingga PostgREST mengekspos seluruh
   tabel ke pemegang anon key yang bersifat publik.
4. Respons (mitigasi): C1 aktifkan RLS dan policy per-pemilik, cabut hak anon; C3
   batasi hak role aplikasi.
5. Verifikasi: curl anon diulang, dibalas HTTP 401 "permission denied for table".
   Bukti: `blueteam/evidence/s2-exfil-after.json`. Loop tertutup.

## S3 - Brute force dan kredensial default

1. Serang (baseline): kredensial default dashboard diterima (HTTP 307), brute force
   login GoTrue tanpa rate limit. Bukti: `blueteam/evidence/s3-brute-before.txt`.
2. Deteksi: diharapkan alert banyak percobaan login gagal (fail2ban, signature
   brute-force Suricata). (Menunggu sensor SO aktif.)
3. Analisis: dashboard masih memakai password bawaan, dan tidak ada pembatasan laju
   percobaan login.
4. Respons (mitigasi): A4 ganti password default dashboard; A1/A2 SSH key-only dan
   root off; A3 fail2ban rate limit SSH.
5. Verifikasi: kredensial default diulang, dibalas HTTP 401. Bukti:
   `blueteam/evidence/s3-brute-after.txt`. Loop tertutup.

## S4 - SYN flood (opsional, availability)

Direncanakan dengan `hping3` ke gateway 8000, skala lab terkontrol. Dikerjakan pada
tahap eksekusi berikutnya, dengan deteksi anomali volume SYN di Security Onion.
