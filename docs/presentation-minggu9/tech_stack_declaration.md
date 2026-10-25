# Deklarasi Tech Stack dan Replikasi Target Node

**Mata Kuliah:** TEK1314 - Keamanan Siber
**Kelompok:** 6 Kelas B
**Dokumen:** Deklarasi Tech Stack (Panduan PBL Bagian III)
**Path repo:** `docs/presentation-minggu9/tech_stack_declaration.md`

---

## 1. Ringkasan proyek IoT asli

Sistem IoT kelompok memakai perangkat ESP32 sebagai node sensor yang mengirim
data operasional ke backend Supabase lewat HTTP REST (PostgREST). Backend
menangani penyimpanan data sensor (PostgreSQL) sekaligus autentikasi pengguna
(Supabase Auth / GoTrue). Pengguna akhir memantau data lewat aplikasi mobile
berbasis Flutter yang membaca data dari Supabase.

## 2. Prinsip replikasi (simulasi vs sistem nyata)

> Sesuai Bagian III Panduan: Target Node BUKAN Supabase Cloud asli proyek.
> Scanning dan eksploitasi terhadap `*.supabase.co` dilarang, karena itu
> infrastruktur milik pihak ketiga (Supabase Inc.) dan berpotensi menyimpan data
> Mitra.

Solusi: membangun replika self-hosted Supabase di Target Node VM lab. Supabase
bersifat open-source dan dirancang untuk self-hosting, sehingga replika dapat
dibangun dari tech stack yang sama persis dengan versi cloud-nya (PostgreSQL,
GoTrue, PostgREST, dan gateway API) lewat Docker Compose. Seluruh data yang
dipakai adalah data dummy, bukan data operasional Mitra.

Karena teknologi di balik Supabase Cloud dan self-hosted identik, kerentanan yang
ditemukan dan kontrol hardening yang dipelajari di simulasi ini sangat mungkin
relevan untuk sistem asli, tetapi risikonya nol terhadap deliverable ke Mitra.

## 3. Penempatan di lab kelompok

Target Supabase menggantikan Target Node generik Fase 1 (Metasploitable 2) pada
slot yang sama di topologi tiga segmen (lihat [ip_plan](../design/ip_plan.md)):

- Attacker Node (Kali): 10.6.6.10
- Target Node (Ubuntu Server 24.04 + Docker + Supabase self-hosted): 172.16.6.10
- Monitoring Node (Security Onion): NIC manajemen 192.168.6.10, NIC monitor tanpa IP

## 4. Pemetaan teknologi asli ke Target Node replika

| Komponen | Proyek IoT asli | Direplikasi sebagai (Target Node) |
|---|---|---|
| Sistem operasi backend | Managed oleh Supabase Cloud | Ubuntu Server 24.04 LTS (VM lab) |
| Database | PostgreSQL (managed) | PostgreSQL (container, self-hosted Supabase) |
| Lapisan autentikasi | Supabase Auth (GoTrue, JWT) | GoTrue (container) |
| Protokol komunikasi sensor | HTTP REST via PostgREST | PostgREST (container), di balik gateway |
| API Gateway | Kong/Envoy (managed) | Envoy (container) di versi self-host yang dipakai |
| Dashboard / monitoring | Aplikasi mobile Flutter (klien) | Supabase Studio (dashboard web bawaan), di balik gateway |

### Catatan soal dashboard

Aplikasi mobile Flutter di proyek asli adalah aplikasi klien, bukan komponen
backend yang menjadi target serangan. Yang direplikasi dan di-harden di Target
Node adalah permukaan backend yang diekspos ke jaringan, yaitu REST API
(PostgREST), endpoint Auth (GoTrue), dan dashboard administratif (Supabase
Studio), yang semuanya dijangkau lewat gateway.

### Catatan versi gateway

Versi supabase/docker yang terpasang memakai Envoy sebagai gateway API, bukan
Kong seperti pada dokumen Supabase lama. Prinsipnya sama (satu pintu masuk),
hanya berkas konfigurasinya berbeda.

## 5. Komponen di Target Node dan port

Yang penting dibedakan: port internal container vs port yang benar-benar diekspos
ke jaringan lab.

| Service | Fungsi | Port internal | Terekspos ke jaringan? |
|---|---|---|---|
| Envoy (gateway) | pintu masuk seluruh REST/Auth traffic | 8000 | Ya, 8000 (satu-satunya yang semestinya) |
| PostgREST | REST API otomatis di atas tabel | 3000 | Tidak, hanya lewat Envoy |
| GoTrue (Auth) | pendaftaran dan login (JWT) | 9999 | Tidak, hanya lewat Envoy |
| Supabase Studio | dashboard admin | 3000 (container sendiri) | Tidak, hanya lewat Envoy |
| PostgreSQL | penyimpanan data sensor dan user | 5432 | Hanya lewat pooler |
| Supavisor (pooler) | connection pooler Postgres | 5432, 6543 | Ya pada kondisi default (celah) |
| SSH (OS) | administrasi VM | 22 | Ya |

Hasil nmap nyata pada kondisi default (rapuh): port 22, 5432, 6543, dan 8000
terbuka. Daftar ini menjadi baseline, lalu tujuan hardening adalah menutup pooler
(5432/6543) dan hanya menyisakan gateway (8000) plus SSH yang dibatasi. Bukti ada
di [evidence/s1-nmap-before.txt](../blueteam/evidence/s1-nmap-before.txt) dan
[evidence/s1-nmap-after.txt](../blueteam/evidence/s1-nmap-after.txt).

---

*Deklarasi ini disepakati Lead, Red Team, dan Blue Team sebelum sesi praktikum Fase 2.*
