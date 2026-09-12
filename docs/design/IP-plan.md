# IP Plan

Ini adalah gambaran untuk lab kami nantinya. Gambar topologinya ada di [topology.png](topology.png).

## Tabel IP Plan

| Hostname                                         | IP Address                        | OS Direncanakan    |
|--------------------------------------------------|-----------------------------------|--------------------|
| Attacker Node (`kali-attacker`)                  | 10.6.6.10/24                      | Kali Linux         |
| Target Node (`metasploitable2`)                  | 172.16.6.10/24                    | Metasploitable 2   |
| Monitoring Node (`securityonion`), NIC manajemen | 192.168.6.10/24                   | Security Onion 2.4 |
| Monitoring Node (`securityonion`), NIC monitor   | tanpa IP (mode sniffing)          | Security Onion 2.4 |
| Router (`router`)                                | 10.6.6.1, 172.16.6.1, 192.168.6.1 | Cisco IOS          |

## Segmen Jaringan

Lab ini dibagi jadi tiga segmen IP. Ketiganya nanti ketemu di satu router, ditambah satu port khusus untuk mirror.

| Segmen                 | Network        | Gateway     | Interface Router | Isi Segmen                    |
|------------------------|----------------|-------------|------------------|-------------------------------|
| Attacker               | 10.6.6.0/24    | 10.6.6.1    | G0/0             | Kali Linux                    |
| Target                 | 172.16.6.0/24  | 172.16.6.1  | G0/1             | Metasploitable 2              |
| Monitoring (manajemen) | 192.168.6.0/24 | 192.168.6.1 | G0/2             | Security Onion, NIC manajemen |
| Mirror                 | tanpa IP       | tanpa IP    | G0/3             | Security Onion, NIC monitor   |

## Detail Interface per Host

| Hostname          | Interface | IP Address   | Netmask       | Gateway    |Fungsi                            |
|-------------------|-----------|--------------|---------------|-------------|-----------------------------------|
| `router`          | G0/0      | 10.6.6.1     | 255.255.255.0 | -           | Gateway segmen Attacker           |
| `router`          | G0/1      | 172.16.6.1   | 255.255.255.0 | -           | Gateway segmen Target             |
| `router`          | G0/2      | 192.168.6.1  | 255.255.255.0 | -           | Gateway segmen Monitoring         |
| `router`          | G0/3      | tanpa IP     | -             | -           | Port tujuan mirror                |
| `kali-attacker`   | eth0      | 10.6.6.10    | 255.255.255.0 | 10.6.6.1    | Melancarkan serangan              |
| `metasploitable2` | eth0      | 172.16.6.10  | 255.255.255.0 | 172.16.6.1  | Korban serangan                   |
| `securityonion`   | NIC 1     | 192.168.6.10 | 255.255.255.0 | 192.168.6.1 | Manajemen (web console, SSH)      |
| `securityonion`   | NIC 2     | tanpa IP     | -             | -           | Monitor (menangkap trafik mirror) |


Nama interface di tabel (`eth0`, NIC 1, NIC 2) cuman placeholder. Nama aslinya mengikuti hasil `ip link` di tiap mesin, misalnya `enp1s0` dan `enp2s0` di VM KVM.

## Tabel Routing

Semua segmen menempel langsung ke router yang sama. Jadi router cukup memakai rute *directly connected*, tanpa rute statis atau protokol routing.

| Network Tujuan | Interface Keluar | Jenis Rute |
|----------------|------------------|------------|
| 10.6.6.0/24    | G0/0             | Connected  |
| 172.16.6.0/24  | G0/1             | Connected  |
| 192.168.6.0/24 | G0/2             | Connected  |

Tiap host cukup memakai gateway di segmennya sendiri sebagai default route.

## Dua Interface Security Onion

Security Onion memakai dua interface dengan fungsi berbeda.

**NIC 1 (manajemen)** punya IP statis `192.168.6.10/24` dan tersambung ke G0/2. Lewat interface ini kita bisa membuka web console (SOC), login SSH, dan mengelola sensor. Dokumentasi Security Onion juga menyarankan memakai IP statis untuk interface manajemen.

**NIC 2 (monitor)** tidak ada IP sama sekali, sesuai dokumentasi Security Onion hanya untuk interface sniffing. Interface ini hanya menerima salinan trafik dari port mirror G0/3, lalu Suricata dan Zeek menganalisisnya. Karena tidak punya IP, interface ini tidak bisa disapa dari jaringan lab. Sensor pun tetap tersembunyi dari attacker.

Kenapa dipisah? Karena ini menjaga data supaya tetap bersih. Yang dianalisis hanya trafik lab, bukan trafik akses Anda ke dashboard.

## Penempatan Monitoring Node

| Parameter            | Nilai                                                                               |
|----------------------|-------------------------------------------------------------------------------------|
| Sumber mirror        | G0/0 (Attacker) dan G0/1 (Target), dua arah (rx dan tx)                             |
| Tujuan mirror        | G0/3, tersambung ke NIC 2 Security Onion                                            |
| Trafik yang terlihat | Semua trafik keluar masuk segmen Attacker dan Target, termasuk scan dan eksploitasi |

G0/2 sengaja tidak ikut dimirror. Itu cuma berisi traffic manajemen Security Onion sendiri, jadi kalau ikut dimirror, dia bakalan ngerekam aksesnya sendiri.

Cara teknis membuat mirror (SPAN di switch, fitur ekspor trafik di router, atau mirror di level hypervisor) masih disesuaikan dengan platform lab. Bagian ini akan diperbarui setelah implementasi diuji.

## Kebutuhan Minimum Security Onion

Menurut dokumentasi resmi Security Onion 2.4, mode EVAL butuh minimal 4 core CPU, 8 GB RAM, storage 200 GB, dan **2 NIC**. Jadi desain dua interface di atas memang mengikuti syarat dari security onion juga.

## Sumber

- Security Onion Documentation 2.4, *Hardware Requirements*: https://docs.securityonion.net/en/2.4/hardware.html
- Rapid7, *Metasploitable 2*: https://docs.rapid7.com/metasploit/metasploitable-2/
