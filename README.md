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
