#!/bin/sh
# Network hardening pada router lab (host Linux KVM yang berperan sebagai router).
# Cukup dijalankan sekali:  sudo sh scripts/router-ufw.sh
#
# Pemetaan interface router pada ip_plan ke bridge libvirt:
#   G0/0  virbr-kel6a  10.6.6.1/24     segmen Attacker
#   G0/1  virbr-kel6t  172.16.6.1/24   segmen Target
#   G0/2  virbr-kel6m  192.168.6.1/24  segmen Monitoring (manajemen SO)
#   G0/3  virbr-kel6x  tanpa IP        tujuan mirror (NIC monitor SO)
#
# Kebijakan bawaan ufw di host sudah deny incoming dan deny routed, jadi
# semua yang tidak diizinkan di bawah ini otomatis ditolak. Aturan deny
# ditulis eksplisit supaya kebijakannya terbaca di /etc/ufw/user.rules.
set -e

ATT=virbr-kel6a
TGT=virbr-kel6t
MGMT=virbr-kel6m
NET_ATT=10.6.6.0/24
NET_TGT=172.16.6.0/24

# 1. Jalur serangan yang memang diskenariokan: Attacker ke Target.
#    Balasan dari Target lolos lewat aturan ESTABLISHED bawaan ufw.
ufw route allow in on $ATT out on $TGT from $NET_ATT to $NET_TGT comment 'kel6: attacker ke target'

# 2. Target tidak boleh membuka koneksi baru ke Attacker
#    (mencegah reverse shell keluar dari target yang sudah jebol).
ufw route deny in on $TGT out on $ATT comment 'kel6: target ke attacker ditolak'

# 3. Segmen Monitoring terlarang bagi Attacker dan Target, supaya
#    konsol Security Onion tidak bisa disentuh dari segmen lab.
ufw route deny in on $ATT out on $MGMT comment 'kel6: attacker ke monitoring ditolak'
ufw route deny in on $TGT out on $MGMT comment 'kel6: target ke monitoring ditolak'

# 4. Segmen lab tidak boleh keluar ke internet lewat Wi-Fi host.
ufw route deny in on $ATT comment 'kel6: attacker ke luar lab ditolak'
ufw route deny in on $TGT comment 'kel6: target ke luar lab ditolak'

# 5. Segmen lab tidak boleh mengakses layanan di host (router) itu sendiri.
ufw deny in on $ATT comment 'kel6: attacker ke router ditolak'
ufw deny in on $TGT comment 'kel6: target ke router ditolak'

# 6. before.rules bawaan ufw meloloskan ICMP echo-request di rantai forward
#    SEBELUM aturan user di atas dibaca. Akibatnya Attacker tetap bisa ping
#    segmen Monitoring. Blok berikut disisipkan tepat setelah aturan
#    ESTABLISHED, jadi balasan tetap lolos tapi paket baru di luar jalur
#    Attacker ke Target dibuang, termasuk ICMP.
BEFORE=/etc/ufw/before.rules
if ! grep -q 'BEGIN kel6' $BEFORE; then
    cp $BEFORE $BEFORE.sebelum-kel6
    sed -i '/^-A ufw-before-forward -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT$/a\
# BEGIN kel6 (lab PBL TEK1314)\
-A ufw-before-forward -i virbr-kel6a ! -o virbr-kel6t -j DROP\
-A ufw-before-forward -i virbr-kel6t -j DROP\
# END kel6' $BEFORE
fi

ufw reload
ufw status numbered
sed -n '/BEGIN kel6/,/END kel6/p' $BEFORE
