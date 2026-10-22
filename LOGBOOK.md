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
