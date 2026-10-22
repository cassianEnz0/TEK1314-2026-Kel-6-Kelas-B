#!/bin/bash
# Memindah IP manajemen Security Onion 2.4 (EVAL, single node) ke segmen
# Monitoring sesuai ip_plan. Jalankan DI DALAM Security Onion, lewat SSH
# dari IP lama:  sudo bash so-pindah-ip.sh
#
# Urutan kerja mengikuti isi skrip resmi so-ip-update (2.4/main):
#   1. Konfigurasi permanen NIC manajemen diganti ke IP baru (belum aktif).
#   2. IP baru dipasang sementara sebagai alamat kedua, karena so-ip-update
#      menjalankan state Salt yang harus bisa menjangkau IP baru.
#   3. so-ip-update mengganti IP lama di /etc dan /opt/so/saltstack.
#   4. Subnet Monitoring dimasukkan ke hostgroup analyst supaya SOC bisa
#      dibuka dari router 192.168.6.1.
#   5. VM dimatikan. NIC-nya dipindah ke jaringan kel6-mgmt dari host.
set -e

IFACE=enp1s0
IP_BARU=192.168.6.10
PREFIX=24
GW=192.168.6.1
SUBNET_ANALIS=192.168.6.0/24

CON=$(nmcli -g GENERAL.CONNECTION device show $IFACE)
echo "Koneksi NetworkManager untuk $IFACE: $CON"

nmcli con mod "$CON" ipv4.method manual ipv4.addresses $IP_BARU/$PREFIX \
    ipv4.gateway $GW ipv4.dns $GW
ip addr add $IP_BARU/$PREFIX dev $IFACE 2>/dev/null || true

# Jawab "y" pada pertanyaan pertama dan "N" pada pertanyaan reboot.
NEW_IP=$IP_BARU so-ip-update

so-firewall includehost analyst $SUBNET_ANALIS

echo "Selesai. VM akan dimatikan dalam 5 detik."
sleep 5
shutdown -h now
