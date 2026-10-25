# Logbook Kelompok 6 Kelas B

Catatan kegiatan proyek PBL TEK1314 Keamanan Siber. Entri terbaru di bawah. Bagian bertanda `[isi]` masih perlu dilengkapi anggota yang bersangkutan.

## Anggota dan Peran

| Nama   | NIM    | Peran                         |
|--------|--------|-------------------------------|
| [isi]  | [isi]  | Lead Analyst                  |
| [isi]  | [isi]  | Red Team                      |
| [isi]  | [isi]  | Blue Team                     |

## Minggu 1 sampai 2: Persiapan Tools

- 31 Agustus 2026: repository kelompok dibuat.
- 1 September 2026: Security Onion 2.4.211 terpasang di KVM (mode EVAL) di laptop utama.
- 6 September 2026: screenshot CyberOps VM dan dashboard Security Onion dari laptop utama dan laptop cadangan diunggah ke `docs/Laptop Utama` dan `docs/Laptop Backup`.
- PIC: [isi]

## Minggu 3 sampai 4: Desain Topologi dan IP Plan

- 12 September 2026: topologi logis (`docs/design/topology.png`) dan skema IP (`docs/design/ip_plan.md`) diunggah. Skenario dan pilihan OS target (Metasploitable 2) ditulis di README.
- PIC: [isi]

## Minggu 5: Logging Check

- [isi: tanggal dan kegiatan logging check Minggu 5 kalau sudah dilakukan saat itu]
- 28 September 2026: logging check diulang di topologi final. Ping dari Kali (10.6.6.10) ke target (172.16.6.10) terekam di Security Onion. Bukti di `docs/phase-1-baseline/assets/`.
- PIC: [isi]

## Minggu 6: Implementasi Lab dan Hardening

28 September 2026:

- Topologi tiga segmen dari ip_plan diwujudkan di KVM. Host laptop berperan sebagai router, port mirror dibuat dengan `tc`. Definisi jaringan dan skrip ada di `scripts/`.
- VM Kali Linux 2026.2 ditambahkan sebagai Attacker Node (`kali-attacker`, 10.6.6.10).
- Metasploitable 2 dipindah ke segmen Target, hostname diganti `SRV-WEB-KEL06B`, IP statis 172.16.6.10.
- Hardening target: iptables default drop, layanan di luar lingkup dimatikan (dari sekitar 30 port jadi 5), akun admin non-root `webadmin`, SSH root dan `msfadmin` ditolak.
- Hardening router: aturan ufw antar segmen, termasuk perbaikan celah ICMP di `before.rules`.
- IP manajemen Security Onion dipindah ke 192.168.6.10 dengan `so-ip-update`.
- PIC: [isi]

## Minggu 7: Demo Progres Fase 1

- `docs/phase-1-baseline/baseline-report.md` selesai, struktur folder repository disesuaikan dengan panduan.
- Demo: [isi tanggal dan catatan dari dosen]
- PIC: [isi]

## Fase 2: Vulnerability Assessment (Replika Self-Hosted Supabase)

26 Oktober 2026:

- Target Node generik Fase 1 (Metasploitable 2) diganti replika self-hosted Supabase di slot IP yang sama (172.16.6.10), karena Fase 2 menyerang replika backend proyek IoT kelompok, bukan Supabase Cloud asli. Alasan dan pemetaan komponen di `docs/phase-2-va/tech_stack_declaration.md`.
- Target dibangun di Ubuntu Server 24.04 + Docker, stack resmi supabase/docker (PostgreSQL, GoTrue, PostgREST, gateway Envoy, Studio), dengan data dummy. Skrip di `scripts/phase-2/provision-supabase.sh`.
- Attack plan Red Team disusun: 4 skenario (recon, data exfiltration via REST, brute force, SYN flood opsional). Dokumen di `docs/phase-2-va/attack_plan.md`, skrip di `scripts/phase-2/attack/`.
- Hardening Blue Team diterapkan dan diverifikasi: RLS, ganti kredensial default, pooler ke loopback, matikan service tak dipakai, UFW, SSH key-only, fail2ban. Dokumen di `docs/phase-2-va/hardening_plan.md` dan `hardening_checklist.md`, skrip di `scripts/phase-2/harden-supabase.sh`.
- Bukti before/after (nmap, exfiltrasi, kredensial default) di `docs/phase-2-va/evidence/`. Hasil terverifikasi: port terbuka turun dari 4 jadi 2, exfiltrasi anon berubah jadi HTTP 401, kredensial default dashboard jadi HTTP 401.
- PIC: [isi]
