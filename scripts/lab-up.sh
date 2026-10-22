#!/bin/sh
# Menyalakan lab Kelompok 6: jaringan, port mirror, lalu VM.
# Jalankan setiap kali sebelum praktik atau demo:  sudo sh scripts/lab-up.sh
#
# Port mirror (peran G0/3 di ip_plan) dibuat dengan tc: semua frame yang
# masuk dan keluar di bridge segmen Attacker dan Target disalin ke bridge
# virbr-kel6x, tempat NIC monitor Security Onion tersambung. Aturan tc
# hilang setiap kali bridge dibuat ulang, karena itu skrip ini perlu
# dijalankan ulang setelah host reboot.
set -e

V="virsh -c qemu:///system"
SUMBER_MIRROR="virbr-kel6a virbr-kel6t"
TUJUAN_MIRROR=virbr-kel6x

echo "== Jaringan"
for net in kel6-attacker kel6-target kel6-mgmt kel6-mirror; do
    $V net-info $net | grep -q 'Active: *yes' || $V net-start $net
done

echo "== Port mirror"
for dev in $SUMBER_MIRROR; do
    tc qdisc del dev $dev clsact 2>/dev/null || true
    tc qdisc add dev $dev clsact
    tc filter add dev $dev ingress matchall action mirred egress mirror dev $TUJUAN_MIRROR
    tc filter add dev $dev egress  matchall action mirred egress mirror dev $TUJUAN_MIRROR
    echo "$dev -> $TUJUAN_MIRROR (rx dan tx)"
done

echo "== VM"
for vm in securityonion metasploitable2 kali-attacker; do
    $V domstate $vm | grep -q running || $V start $vm
done
$V list
