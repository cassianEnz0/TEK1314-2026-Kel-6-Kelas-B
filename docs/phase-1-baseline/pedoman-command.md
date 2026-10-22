# Pedoman Command Lab Fase 1

Daftar perintah yang dipakai membangun, menjalankan, dan mendemokan lab Kelompok 6 Kelas B. Tiap perintah disertai tempat menjalankannya, sasarannya, fungsinya, dan alasannya. Pedoman ini pendamping skrip di [../../scripts/](../../scripts/); skrip mengotomatiskan perintah-perintah ini, dokumen ini menjelaskan isinya satu per satu.

## Peta lokasi

Sebelum menyalin perintah, pahami dulu Anda sedang berada di mesin mana. Ada empat tempat berbeda, dan salah tempat bisa berakibat fatal.

- **Host (router).** Laptop itu sendiri. Di lab ini laptop merangkap router antar segmen, jadi semua perintah `virsh`, `tc`, `ufw`, dan `tcpdump` dijalankan di sini, di terminal biasa. Gateway tiap segmen (10.6.6.1, 172.16.6.1, 192.168.6.1) adalah host ini.
- **Target (`SRV-WEB-KEL06B`).** VM Metasploitable 2 di 172.16.6.10. Perintah hardening target dijalankan di dalam VM ini sebagai root.
- **Security Onion.** VM sensor di 192.168.6.10 (NIC manajemen). SOC diakses lewat browser, konfigurasi IP dijalankan di dalam VM-nya.
- **Kali (`kali-attacker`).** VM penyerang di 10.6.6.10. Dipakai membangkitkan trafik uji.

## Di host (router)

### Membuat jaringan sekali di awal

```
virsh -c qemu:///system net-define scripts/libvirt/kel6-attacker.xml
virsh -c qemu:///system net-autostart kel6-attacker
virsh -c qemu:///system net-start kel6-attacker
```

Dijalankan di host, diulang untuk keempat berkas (`kel6-attacker`, `kel6-target`, `kel6-mgmt`, `kel6-mirror`). `net-define` mendaftarkan jaringan ke libvirt, `net-autostart` membuatnya hidup tiap boot, `net-start` menyalakannya sekarang. Keempat jaringan ini yang menjadi empat interface router pada ip_plan. Tiap berkas XML memakai `forward mode='open'` supaya libvirt tidak memasang NAT atau firewall sendiri, jadi seluruh kendali ada di ufw host.

### Menyalakan lab tiap sebelum praktik

```
sudo sh scripts/lab-up.sh
```

Dijalankan di host sebagai root. Skrip ini menyalakan keempat jaringan, memasang port mirror dengan `tc`, lalu menghidupkan ketiga VM. Perlu diulang tiap kali setelah laptop reboot, karena aturan `tc` hilang saat bridge dibuat ulang. Isinya tiga blok di bawah ini.

### Port mirror

```
tc qdisc add dev virbr-kel6a clsact
tc filter add dev virbr-kel6a ingress matchall action mirred egress mirror dev virbr-kel6x
tc filter add dev virbr-kel6a egress  matchall action mirred egress mirror dev virbr-kel6x
```

Dijalankan di host, mengarah ke bridge segmen Attacker (`virbr-kel6a`) dan diulang untuk bridge Target (`virbr-kel6t`). `clsact` menambahkan qdisc yang bisa memfilter arah masuk dan keluar. Dua `filter` menyalin semua frame, baik yang masuk maupun keluar, ke `virbr-kel6x`, tempat NIC monitor Security Onion menempel. Hasilnya setara SPAN di switch: sensor menerima salinan trafik tanpa ikut di jalur. Karena dua bridge sumber sama-sama disalin, paket Attacker ke Target tertangkap dua kali.

### Firewall router sekali di awal

```
sudo sh scripts/router-ufw.sh
```

Dijalankan di host sebagai root. Memasang kebijakan ufw antar segmen. Aturan utamanya: hanya Attacker ke Target yang diizinkan (`ufw route allow in on virbr-kel6a out on virbr-kel6t`), selebihnya ditolak. Skrip ini juga menyisipkan blok di `/etc/ufw/before.rules` untuk menutup celah ICMP: `before.rules` bawaan meloloskan echo-request di rantai forward sebelum aturan Anda dibaca, jadi tanpa tambalan ini Attacker tetap bisa ping segmen Monitoring.

### Memeriksa firewall saat demo

```
sudo ufw status numbered
cat /etc/ufw/before.rules | sed -n '/BEGIN kel6/,/END kel6/p'
```

Dijalankan di host. Yang pertama menampilkan aturan bernomor beserta komentar `kel6`, yang kedua menunjukkan tambalan ICMP di `before.rules`. Panduan meminta Anda menunjukkan berkas konfigurasi keamanan, dua perintah ini jawabannya.

### Menangkap trafik di NIC monitor

```
sudo tcpdump -tttt -nn -i virbr-kel6x icmp
```

Dijalankan di host, mengarah ke bridge tujuan mirror. Membuktikan salinan trafik benar-benar tiba di interface tempat sensor Security Onion mendengarkan. Opsi `-tttt` memberi timestamp lengkap, `-nn` mematikan resolusi nama supaya IP dan port terbaca apa adanya.

### Memicu ping dari Kali tanpa SSH

```
virsh -c qemu:///system qemu-agent-command kali-attacker \
  '{"execute":"guest-exec","arguments":{"path":"/bin/ping","arg":["-c","10","172.16.6.10"],"capture-output":true}}'
```

Dijalankan di host, mengarah ke dalam VM Kali lewat qemu-guest-agent. Kali sengaja tidak membuka port apa pun (hasil hardening), jadi tidak bisa di-SSH. Guest agent memungkinkan menjalankan perintah di dalamnya tanpa jaringan. Dipakai di `verifikasi-demo.sh` untuk membangkitkan trafik uji otomatis.

### Verifikasi kesiapan sekali jalan

```
sudo bash scripts/verifikasi-demo.sh
```

Dijalankan di host sebagai root. Menggabungkan langkah di atas: menaikkan mirror, menyimpan status ufw, memicu ping Kali ke Target, dan menangkapnya di NIC monitor. Bukti baru tersimpan ke [assets/](assets/). Pakai ini untuk memastikan seluruh rantai jalan sebelum demo.

## Di Target (SRV-WEB-KEL06B)

Semua perintah berikut dibungkus `scripts/harden-target.sh`, dijalankan sebagai root di dalam VM target: `sudo sh harden-target.sh <password-webadmin>`. Dirinci di sini supaya tiap keputusannya jelas.

### Identitas

```
echo SRV-WEB-KEL06B > /etc/hostname
hostname SRV-WEB-KEL06B
```

Mengganti hostname sesuai format panduan (`SRV-WEB-KEL0xF/G`). Konfigurasi IP statis 172.16.6.10 ditulis ke `/etc/network/interfaces` dengan gateway 172.16.6.1, plus `pre-up iptables-restore` supaya aturan firewall dimuat sebelum interface menyala.

### Mematikan layanan di luar lingkup

```
/etc/init.d/<layanan> stop
update-rc.d -f <layanan> remove
```

Dijalankan untuk tiap layanan tak terpakai (bind9, distcc, mysql, postgresql, proftpd, samba, dan lainnya). `stop` menghentikan sekarang, `update-rc.d -f ... remove` mencabutnya dari urutan boot. Layanan inetd (telnet, rsh, bindshell 1524) dimatikan dengan mengomentari `/etc/inetd.conf`, dan layanan di `rc.local` (rmiregistry, UnrealIRCd, VNC, druby) dihapus dari situ. Alasannya tegas: layanan yang mati tidak bisa diserang sama sekali, beda dari sekadar diblokir firewall.

### Akun

```
useradd -m -s /bin/bash -G admin webadmin
passwd -l user
passwd -l service
```

Membuat admin non-root `webadmin` dan mengunci akun bawaan yang tak dipakai. Akses SSH dibatasi di `/etc/ssh/sshd_config` dengan `PermitRootLogin no` dan `AllowUsers webadmin`, jadi root dan msfadmin ditolak masuk lewat SSH walau akunnya masih ada.

### Firewall target

```
iptables-restore < /etc/iptables.rules
```

Memuat aturan dengan kebijakan `INPUT DROP`. Hanya yang diizinkan yang lewat: ICMP echo-request dari Attacker, Monitoring, dan router; TCP 21, 80, 8180 dari Attacker (bahan serangan fase 2); dan TCP 22 hanya dari Monitoring dan router. iptables mentah dipilih, bukan ufw, karena Ubuntu 8.04 terlalu tua untuk ufw versi awal.

### Memeriksa hasil hardening

```
sudo netstat -tulpn
sudo iptables -L -n -v
sudo passwd -S root msfadmin webadmin
```

Dijalankan di target untuk bukti. `netstat` harus menyisakan lima port saja (21, 80, 3306, 8009, 8180) plus SSH. `iptables -L` menunjukkan kebijakan DROP dan daftar izin. `passwd -S` menunjukkan status tiap akun.

## Di Security Onion

### Memindah IP manajemen

```
sudo bash so-pindah-ip.sh
```

Dijalankan di dalam VM Security Onion lewat SSH dari IP lama. Membungkus `so-ip-update` resmi untuk memindah IP manajemen ke 192.168.6.10, lalu `so-firewall includehost analyst 192.168.6.0/24` supaya SOC bisa dibuka dari router 192.168.6.1. Lakukan snapshot VM dulu sebagai jalan kembali.

### Mengakses SOC saat demo

```
https://192.168.6.10
```

Dibuka di browser host. Setelah login, masuk menu Hunt, set rentang waktu, lalu saring dengan:

```
source.ip:10.6.6.10 AND destination.ip:172.16.6.10
```

Menampilkan event ICMP dari Kali ke Target lengkap dengan timestamp dan alamat. Inilah bukti perekaman sisi sensor yang diminta panduan. Sguil dan Squert yang disebut panduan sudah dihapus sejak Security Onion 2, fungsinya pindah ke SOC.

## Di Kali (kali-attacker)

### Membangkitkan trafik uji

```
ping -c 10 172.16.6.10
```

Dijalankan di dalam Kali, mengarah ke Target. Trafik ini melewati router, dimirror ke sensor, lalu muncul di SOC. Saat demo, jalankan dari terminal Kali langsung.

### Memastikan Kali tidak membuka layanan

```
ss -tulpn
```

Dijalankan di dalam Kali. Keluarannya harus kosong. Attacker tidak perlu melayani apa pun, jadi tidak ada permukaan serangan balik ke arahnya.
