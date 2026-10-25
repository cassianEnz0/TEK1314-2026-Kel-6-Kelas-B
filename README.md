# TEK1314-2026-Kel-6-Kelas-B



## Skenario Proyek

Proyek ini mensimulasikan serangan terhadap server rentan, lalu mendeteksinya lewat pemantauan jaringan.

Lab terdiri dari tiga node yang ditempatkan di tiga segmen berbeda dan dihubungkan oleh satu router

**Alur skenario:**

1. Red Team memakai Kali Linux untuk scanning ke Target Node dan mencari layanan yang terbuka.
2. Red Team mengeksploitasi layanan rentan bawaan Metasploitable 2. Trafik serangan melintas dari segmen Attacker ke segmen Target lewat router.
3. Router melakukan mirror terhadap trafik segmen Attacker dan Target ke interface monitor Security Onion.
4. Blue Team menganalisis alert dan log di Security Onion untuk mengenali jejak serangan.

Metasploitable 2 dipilih karena menyediakan banyak vulnerability dan juga ringan, sehingga vm ini sangat cocok untuk laptop dengan RAM terbatas. Daftar port dan celah yang akan dieksploitasi disusun oleh Red Team.

Security Onion memakai dua interface. Interface manajemen (192.168.6.10) dipakai untuk mengakses web console. Interface monitor tidak diberi IP dan hanya menangkap trafik mirror, jadi tidak akan terlihat oleh attacker.

Detail desain jaringan:

- Topologi: [docs/design/topology.png](docs/design/topology.png)
- Skema IP dan routing: [docs/design/ip_plan.md](docs/design/ip_plan.md)

## Struktur Repository

```
docs/
  design/              Minggu 4: topologi dan IP plan
  phase-1-baseline/    Minggu 5 sampai 7: baseline report, bukti hardening dan logging
  presentation-minggu9/ Minggu 9: slide (slides.pdf) dan deklarasi tech stack
  blueteam/            Fase 2: hardening checklist, plan, dan bukti before/after
  redteam/             Fase 2: attack plan dan bukti eksekusi serangan
  purple-team-log.md   Fase 2: log 5 tahap Purple Team Loop per skenario
  phase-3-incident/    Fase 3: incident response (belum dimulai)
scripts/               Skrip untuk membangun ulang lab, hardening, dan Fase 2
LOGBOOK.md             Catatan kegiatan per minggu
```

## Progres

- Fase 1 (baseline dan hardening): [docs/phase-1-baseline/baseline-report.md](docs/phase-1-baseline/baseline-report.md)
- Fase 2 Deklarasi Tech Stack: [docs/presentation-minggu9/tech_stack_declaration.md](docs/presentation-minggu9/tech_stack_declaration.md)
- Fase 2 Blue Team (hardening): [docs/blueteam/hardening_checklist.md](docs/blueteam/hardening_checklist.md), [docs/blueteam/hardening_plan.md](docs/blueteam/hardening_plan.md)
- Fase 2 Red Team (attack plan): [docs/redteam/attack_plan.md](docs/redteam/attack_plan.md)
- Fase 2 Purple Team Loop: [docs/purple-team-log.md](docs/purple-team-log.md)
- Pedoman command lab: [docs/phase-1-baseline/pedoman-command.md](docs/phase-1-baseline/pedoman-command.md)
- Logbook: [LOGBOOK.md](LOGBOOK.md)

> Catatan Fase 2: Target Node generik Fase 1 (Metasploitable 2) diganti replika
> self-hosted Supabase di slot IP yang sama (172.16.6.10), karena Fase 2 menyerang
> replika backend proyek IoT kelompok, bukan Supabase Cloud asli milik Mitra.

## Menyalakan Lab

Lab berjalan di KVM/libvirt. Host laptop berperan sebagai router antar segmen.

1. Sekali saja: buat jaringan dari `scripts/libvirt/*.xml` dengan `virsh net-define` lalu `virsh net-autostart`, kemudian jalankan `sudo sh scripts/router-ufw.sh`.
2. Setiap kali sebelum praktik: `sudo sh scripts/lab-up.sh` untuk memasang port mirror dan menyalakan VM.
