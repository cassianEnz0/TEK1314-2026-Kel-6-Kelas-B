# Baseline Report Fase 1: Hardening Review

Mata kuliah TEK1314 Keamanan Siber, Kelompok 6 Kelas B.
Target: demo progres Minggu 7 (sistem "before attack").

Laporan ini mencatat kondisi lab sebelum fase simulasi serangan: topologi yang benar-benar berjalan, identitas tiap node, hardening yang kami pasang beserta alasannya, dan bukti bahwa Security Onion sudah merekam trafik lab. Semua bukti ada di folder [assets/](assets/), dan semua konfigurasi bisa diulang dari skrip di folder [scripts/](../../scripts/).

## 1. Topologi yang Diimplementasikan

Desain logisnya tetap sama dengan dokumen Minggu 4 ([topology.png](../design/topology.png) dan [ip_plan.md](../design/ip_plan.md)): tiga segmen, satu router, dan satu port mirror ke Security Onion.

Lab berjalan di satu laptop dengan KVM/libvirt. Peran router Cisco di diagram diambil alih oleh host Linux itu sendiri. Tiap interface router menjadi satu bridge libvirt:

| Interface di diagram | Bridge di host | Alamat router   | Segmen                           |
|----------------------|----------------|-----------------|----------------------------------|
| G0/0                 | `virbr-kel6a`  | 10.6.6.1/24     | Attacker                         |
| G0/1                 | `virbr-kel6t`  | 172.16.6.1/24   | Target                           |
| G0/2                 | `virbr-kel6m`  | 192.168.6.1/24  | Monitoring (manajemen SO)        |
| G0/3                 | `virbr-kel6x`  | tanpa IP        | Tujuan mirror (NIC monitor SO)   |

Ketiga jaringan beralamat memakai mode `forward mode='open'` di libvirt. Di mode ini libvirt tidak memasang NAT maupun aturan firewall sendiri, jadi seluruh keputusan routing dan filtering ada di satu tempat, yaitu ufw di host. Efek sampingnya menguntungkan: lab tidak punya jalan keluar ke internet, sehingga Metasploitable yang rentan tidak pernah terpapar jaringan luar. Definisi jaringannya ada di [scripts/libvirt/](../../scripts/libvirt/).

Port mirror dibuat dengan `tc`. Semua frame yang masuk dan keluar di bridge Attacker dan Target disalin ke bridge `virbr-kel6x` dengan aksi `mirred`. Cara kerjanya setara dengan SPAN di switch: Security Onion menerima salinan trafik tanpa ikut berada di jalur trafik itu. Skripnya ada di [scripts/lab-up.sh](../../scripts/lab-up.sh).

Alur data saat demo:

1. Kali (10.6.6.10) mengirim paket ke Metasploitable (172.16.6.10) lewat gateway 10.6.6.1.
2. Host meneruskan paket dari `virbr-kel6a` ke `virbr-kel6t` setelah lolos pemeriksaan ufw.
3. Di saat yang sama, `tc` menyalin paket di kedua bridge itu ke `virbr-kel6x`.
4. Suricata dan Zeek di Security Onion membaca salinan tersebut dari NIC monitor, lalu hasilnya tampil di Security Onion Console (SOC) yang diakses lewat 192.168.6.10.

## 2. Identitas Node

Hasil verifikasi langsung di tiap mesin (bukan sekadar rencana):

| Node       | Hostname         | IP              | Gateway     | OS                                     |
|------------|------------------|-----------------|-------------|----------------------------------------|
| Attacker   | `kali-attacker`  | 10.6.6.10/24    | 10.6.6.1    | Kali Linux 2026.2 (image QEMU resmi)   |
| Target     | `SRV-WEB-KEL06B` | 172.16.6.10/24  | 172.16.6.1  | Metasploitable 2 (Ubuntu 8.04)         |
| Monitoring | `securityonion`  | 192.168.6.10/24 | 192.168.6.1 | Security Onion 2.4.211 (EVAL)          |
| Router     | host laptop      | lihat tabel 1   | -           | Linux, KVM/libvirt 12.7, ufw           |

Hostname target mengikuti format panduan `SRV-WEB-KELxx`, dengan nomor kelompok dua digit dan huruf kelas.

Bukti: [kali-identitas.png](assets/kali-identitas.png), [target-sesudah-hardening.txt](assets/target-sesudah-hardening.txt), dan [so-identitas.txt](assets/so-identitas.txt).

## 3. Network Hardening

### 3.1 Firewall router (ufw di host)

Kebijakan bawaan ufw di host sudah `deny (incoming)` dan `deny (routed)`. Di atas itu kami menambah aturan yang sempit dan eksplisit, lewat [scripts/router-ufw.sh](../../scripts/router-ufw.sh):

- Attacker boleh membuka koneksi ke Target. Ini satu-satunya jalur yang memang diskenariokan.
- Target tidak boleh membuka koneksi baru ke Attacker. Kalau target nanti berhasil dibobol, reverse shell dari target tidak bisa langsung keluar.
- Attacker dan Target sama-sama tidak boleh menyentuh segmen Monitoring, jadi konsol Security Onion aman dari segmen lab.
- Attacker dan Target tidak boleh keluar ke internet atau mengakses layanan di host.

Kami menemukan satu jebakan di ufw. Berkas `/etc/ufw/before.rules` bawaan meloloskan ICMP echo-request di rantai forward sebelum aturan user dibaca. Artinya, tanpa penanganan tambahan, Kali tetap bisa ping konsol Security Onion walaupun aturan user bilang "deny". Karena itu kami menyisipkan dua baris di `before.rules`, tepat setelah aturan ESTABLISHED, yang membuang semua paket baru di luar jalur Attacker ke Target. Balasan yang sah tetap lolos.

Bukti: [router-ufw.txt](assets/router-ufw.txt) (isi `ufw status verbose`, `/etc/ufw/user.rules`, dan blok tambahan di `before.rules`).

### 3.2 Firewall target (iptables)

Metasploitable 2 kami beri kebijakan `INPUT DROP`, lalu hanya membuka yang perlu:

- TCP 21, 80, dan 8180 dari segmen Attacker. Ketiganya lingkup serangan fase 2: vsftpd 2.3.4, Apache (DVWA, Mutillidae, phpMyAdmin), dan Tomcat.
- TCP 22 hanya dari segmen Monitoring dan dari router, khusus untuk administrasi.
- ICMP echo dari segmen Attacker, Monitoring, dan router, supaya uji konektivitas dan logging check bisa jalan.
- Paket yang ditolak dicatat dengan prefix `IPT-DROP` (dibatasi 5 per menit agar log tidak banjir).

IPv6 juga diberi kebijakan `INPUT DROP`, karena beberapa layanan Metasploitable mendengarkan di `:::` dan sebelumnya tidak terlindungi sama sekali.

Aturan disimpan di `/etc/iptables.rules` dan dimuat dari `/etc/network/interfaces` lewat `pre-up`, jadi firewall aktif sebelum interface menyala. Kami menguji ini dengan reboot penuh (uptime 0 menit), dan aturannya tetap terpasang.

Bukti: [target-sebelum-hardening.txt](assets/target-sebelum-hardening.txt) dan [target-sesudah-hardening.txt](assets/target-sesudah-hardening.txt).

## 4. System Hardening

### 4.1 Target (SRV-WEB-KEL06B)

Layanan. Sebelum hardening ada sekitar 30 port yang mendengarkan, termasuk bindshell root di port 1524, telnet, rsh/rlogin/rexec, NFS, Samba, distcc, UnrealIRCd, VNC, dan PostgreSQL. Setelah hardening tinggal lima: 21, 80, 8180, 3306, dan 22. MySQL (3306) tetap hidup karena dipakai DVWA dan Mutillidae, tapi tertutup firewall dari luar. Caranya:

- Layanan dari skrip init dimatikan dan dicabut dari urutan boot dengan `update-rc.d -f <layanan> remove`: bind9, distcc, mysql-ndb, nfs, portmap, postfix, postgresql, proftpd, rsync, samba, dan openbsd-inetd.
- Semua baris di `/etc/inetd.conf` dinonaktifkan. Dari sinilah telnet, tftp, rsh, rlogin, rexec, dan bindshell 1524 berasal.
- `/etc/rc.local` dibersihkan dari rmiregistry, UnrealIRCd, VNC, dan druby.

Hak akses user:

- Dibuat akun admin non-root `webadmin` (grup `admin`, pakai sudo).
- SSH dibatasi `AllowUsers webadmin` dan `PermitRootLogin no`. Login SSH sebagai `msfadmin` sekarang ditolak.
- Akun bawaan `user` dan `service` dikunci (`passwd -l`).

Security patch. Bagian ini tidak bisa kami penuhi, dan kami menyatakannya terus terang. Metasploitable 2 berbasis Ubuntu 8.04 yang sudah lama tidak didukung, dan mesin ini memang dibuat sengaja rentan sebagai bahan fase 2. Menambal celahnya justru menghapus bahan praktikum. Sebagai kompensasi, kami membatasi permukaan serangan lewat firewall dan pengurangan layanan di atas, serta mengisolasi lab dari internet.

Semua langkah di atas ada di [scripts/harden-target.sh](../../scripts/harden-target.sh). Salinan asli berkas yang diubah disimpan dengan akhiran `.asli` di target.

### 4.2 Attacker (kali-attacker)

- Bekerja sebagai user non-root `kali`, perintah root lewat sudo.
- Tidak ada satu pun port yang mendengarkan (`ss -tulpn` kosong).
- Zona waktu disamakan ke Asia/Jakarta supaya timestamp di Kali, target, dan Security Onion bisa dicocokkan.

### 4.3 Monitoring (Security Onion)

- IP manajemen dipindah ke 192.168.6.10 dengan utilitas resmi `so-ip-update`, setelah membuat snapshot VM sebagai jalan kembali. Prosedurnya ada di [scripts/so-pindah-ip.sh](../../scripts/so-pindah-ip.sh).
- Firewall bawaan Security Onion hanya mengizinkan akses analis dari subnet yang terdaftar di hostgroup `analyst`. Kami menambahkan 192.168.6.0/24 lewat `so-firewall includehost`.
- NIC monitor tidak punya IP, jadi sensor tidak bisa disapa dari segmen lab.

## 5. Logging Check (Bukti Kegiatan Minggu 5)

Tujuan bagian ini membuktikan satu hal: trafik yang lewat di segmen lab benar-benar sampai ke sensor Security Onion, bukan sekadar berpindah antar VM. Uji yang dipakai adalah ping ICMP dari Kali (10.6.6.10) ke Target (172.16.6.10), lalu kami periksa apakah salinannya tiba di NIC monitor Security Onion.

Mekanismenya bisa salah paham kalau buktinya diambil dari sisi yang keliru, jadi kami pisahkan dua lapis.

Lapis pertama, pengiriman mirror. NIC monitor Security Onion menempel di bridge `virbr-kel6x`. Kami jalankan `tcpdump -i virbr-kel6x icmp` tepat di bridge itu sambil Kali mengirim sepuluh ping ke Target. Hasilnya 20 echo request dan 20 echo reply, lihat [assets/mirror-icmp-verifikasi.txt](assets/mirror-icmp-verifikasi.txt). Angkanya dua kali lipat dari sepuluh ping karena tiap paket melewati dua bridge yang sama-sama dimirror, segmen Attacker sebelum routing dan segmen Target sesudah routing, jadi sensor menerima dua salinan persis seperti SPAN pada dua port switch. Pengamatan pertama dengan pembacaan TTL (64 untuk salinan pra-routing, 63 untuk pasca-routing) ada di [assets/mirror-icmp.txt](assets/mirror-icmp.txt). Intinya: paket serangan sampai ke interface sensor, dan sensor tidak ikut berada di jalur trafik.

Lapis kedua, perekaman oleh Security Onion. Suricata dan Zeek membaca NIC monitor itu, lalu event-nya tampil di Security Onion Console (SOC) di `https://192.168.6.10`. Tampilan SOC yang menyaring event ICMP 10.6.6.10 ke 172.16.6.10 ada di [assets/so-soc-icmp.png](assets/so-soc-icmp.png), lengkap dengan timestamp, IP asal, dan IP tujuan sesuai skenario kelompok.

Catatan: panduan menyebut screenshot Sguil atau Squert. Keduanya sudah dihapus sejak Security Onion 2, penjelasannya di bagian 7. Fungsi itu kini dipegang SOC, jadi bukti perekaman kami ambil dari sana.

## 6. Alasan Pemilihan Metode Hardening

Router dengan ufw. Semua trafik lab pasti melewati host, jadi satu titik kontrol di sana cukup untuk memisahkan segmen. ufw dipilih karena aturannya terbaca manusia (`ufw status`) dan tersimpan rapi di `/etc/ufw/user.rules`, yang juga dicontohkan di panduan.

iptables di target, bukan ufw. Paket ufw di Ubuntu 8.04 adalah versi awal. iptables mentah lebih bisa diandalkan di sistem setua ini, dan aturannya bisa dimuat sebelum interface menyala.

Default deny di dua lapis. Router dan target sama-sama menolak apa pun yang tidak diizinkan. Kalau satu lapis salah konfigurasi, lapis lainnya masih menahan.

Layanan dimatikan, bukan cuma diblokir. Port yang diblokir firewall masih bisa dieksploitasi dari dalam segmen yang sama atau kalau aturan firewall terhapus. Layanan yang mati tidak bisa diserang sama sekali.

Lingkup port dipertahankan untuk fase 2. Port 21, 80, dan 8180 sengaja dibiarkan terbuka karena itulah bahan simulasi serangan. Hardening fase 1 bertujuan mengecilkan permukaan serangan ke lingkup yang disepakati, bukan menutup semuanya.

## 7. Catatan untuk Panduan

Panduan meminta screenshot Sguil atau Squert. Keduanya sudah tidak ada di Security Onion 2 ke atas. Pengumuman rilis resmi Security Onion 2 menyebut Sguil, Squert, dan CapMe dihapus, lalu fungsinya digantikan Security Onion Console (SOC) yang mencakup manajemen alert, threat hunting, dan pengambilan pcap. Karena lab kami memakai Security Onion 2.4, bukti logging diambil dari SOC.

## Sumber

- Security Onion Solutions, *Security Onion 2 Has Reached General Availability (GA)!*, Oktober 2020: https://blog.securityonion.net/2020/10/security-onion-2-has-reached-general.html
- Security Onion Documentation 2.4, *IP Address*: https://docs.securityonion.net/en/2.4/ip.html
- Security Onion, skrip `so-ip-update` (branch 2.4/main): https://github.com/Security-Onion-Solutions/securityonion/blob/2.4/main/salt/common/tools/sbin/so-ip-update
- Security Onion, skrip `so-firewall` (branch 2.4/main): https://github.com/Security-Onion-Solutions/securityonion/blob/2.4/main/salt/manager/tools/sbin/so-firewall
- libvirt, *Network XML format* (mode `open`): https://libvirt.org/formatnetwork.html
- Rapid7, *Metasploitable 2*: https://docs.rapid7.com/metasploit/metasploitable-2/
- Kali Linux, image QEMU 2026.2 dan SHA256SUMS: https://kali.download/base-images/kali-2026.2/
