# Fase 2 - Vulnerability Assessment (Replika Self-Hosted Supabase)

Fase 2 mengganti Target Node generik Fase 1 (Metasploitable 2) dengan replika
self-hosted dari backend proyek IoT kelompok, yaitu stack Supabase (PostgreSQL,
GoTrue, PostgREST, gateway Envoy, Studio) di Ubuntu Server 24.04 + Docker. Target
menempati slot yang sama di topologi tiga segmen: 172.16.6.10. Red Team menyerang
dari Kali (10.6.6.10), Blue Team mengeraskan dan memantau lewat Security Onion
(192.168.6.10).

Alasan memakai replika, bukan Supabase Cloud asli, dijelaskan di
[tech_stack_declaration.md](tech_stack_declaration.md): Panduan Bagian III
melarang scanning terhadap `*.supabase.co` milik Mitra. Data semuanya dummy.

## Isi folder

- [tech_stack_declaration.md](tech_stack_declaration.md) - deklarasi tech stack dan pemetaan komponen asli ke replika (Bagian III).
- [attack_plan.md](attack_plan.md) - rencana serangan Red Team, 4 skenario (Bagian IX).
- [hardening_checklist.md](hardening_checklist.md) - checklist kontrol Blue Team (Bagian VIII).
- [hardening_plan.md](hardening_plan.md) - rencana teknis hardening plus perintah dan bukti.
- [evidence/](evidence/) - output nmap, exfiltrasi, dan uji kredensial, kondisi rapuh dan hardened.

## Ringkasan hasil before vs after (terverifikasi)

| Uji | Rapuh | Hardened |
|---|---|---|
| nmap port terbuka | 22, 5432, 6543, 8000 | 22, 8000 |
| curl anon ke REST API | seluruh data tabel tumpah | HTTP 401 permission denied |
| kredensial default dashboard | diterima (307) | HTTP 401 |

## Skrip terkait

- `scripts/phase-2/provision-supabase.sh` - memasang Docker lalu menghidupkan stack Supabase dan seed data dummy di Target Node.
- `scripts/phase-2/harden-supabase.sh` - menerapkan seluruh kontrol hardening.
- `scripts/phase-2/attack/` - skrip serangan S1 sampai S3 siap pakai (`source env.sh` dulu untuk anon key).
