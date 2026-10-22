#!/bin/bash
# verifikasi-demo.sh - uji kesiapan demo Fase 1 dari ujung ke ujung.
# Jalankan dengan root:  sudo bash scripts/verifikasi-demo.sh
#
# Yang dibuktikan skrip ini:
#   1. Port mirror aktif di bridge Attacker dan Target.
#   2. Firewall router (ufw) hidup dan aturan kel6 terpasang.
#   3. ICMP nyata dari Kali (10.6.6.10) ke Target (172.16.6.10) benar-benar
#      tiba di NIC monitor Security Onion (virbr-kel6x), ditangkap langsung
#      di sana. Ping dipicu di dalam Kali lewat qemu-guest-agent, tanpa SSH.
# Bukti baru disimpan ke docs/phase-1-baseline/assets/ dengan nama ...-verifikasi.
#
# Setelah skrip selesai, bagian Security Onion (apakah SOC ikut merekam)
# diverifikasi terpisah, lihat petunjuk yang dicetak di akhir.
set -u

REPO="/home/barbaduk/Documents/CyberSecurity/Matkul-Cybersecurity"
AST="$REPO/docs/phase-1-baseline/assets"
V="virsh -c qemu:///system"
MON=virbr-kel6x

echo "== 1. Naikkan jaringan, mirror, dan VM (lab-up.sh)"
sh "$REPO/scripts/lab-up.sh" >/dev/null
gagal=0
for d in virbr-kel6a virbr-kel6t; do
    if tc qdisc show dev "$d" | grep -q clsact; then
        echo "   mirror $d  : AKTIF"
    else
        echo "   mirror $d  : GAGAL"; gagal=1
    fi
done
[ "$gagal" = 1 ] && { echo "Mirror gagal dipasang, hentikan."; exit 1; }

echo
echo "== 2. Firewall router (bukti untuk walkthrough)"
ufw status numbered | tee "$AST/router-ufw-status-verifikasi.txt" | grep -E 'Status:|kel6' || true
echo "   tersimpan: $AST/router-ufw-status-verifikasi.txt"

echo
echo "== 3. Tangkap ICMP di NIC monitor SO ($MON) sambil Kali ping Target"
OUT="$AST/mirror-icmp-verifikasi.txt"
{
    echo "# Bukti verifikasi ulang, $(date '+%Y-%m-%d %H:%M:%S %z')"
    echo "# tcpdump -i $MON icmp, sumber trafik: Kali 10.6.6.10 ping -c 10 ke Target 172.16.6.10"
    echo "# Ping dipicu di dalam Kali lewat qemu-guest-agent (tanpa SSH)."
    echo
} > "$OUT"

timeout 14 tcpdump -tttt -nn -i "$MON" icmp 2>/dev/null >> "$OUT" &
TD=$!
sleep 2

PID=$($V qemu-agent-command kali-attacker \
    '{"execute":"guest-exec","arguments":{"path":"/bin/ping","arg":["-c","10","172.16.6.10"],"capture-output":true}}' \
    2>/dev/null | grep -o '"pid":[0-9]*' | cut -d: -f2)
if [ -n "${PID:-}" ]; then
    echo "   ping dipicu di Kali (guest-exec pid $PID)"
else
    echo "   PERINGATAN: gagal memicu ping lewat guest agent. Ping manual dari Kali sekarang."
fi
wait "$TD" 2>/dev/null

REQ=$(grep -c 'echo request'  "$OUT" || true)
REP=$(grep -c 'echo reply'    "$OUT" || true)
echo "   terlihat di $MON : $REQ echo request, $REP echo reply"
echo "   tersimpan: $OUT"
if [ "${REQ:-0}" -gt 0 ] && [ "${REP:-0}" -gt 0 ]; then
    echo "   HASIL: mirror meneruskan trafik serangan ke sensor SO dua arah. OK."
else
    echo "   HASIL: trafik belum terlihat di monitor. Cek mirror / ping / boot Target."
fi

echo
echo "== 4. Langkah manual terakhir: pastikan SOC ikut merekam"
echo "   Buka Security Onion Console di browser:  https://192.168.6.10"
echo "   Menu Alerts/Hunt, rentang waktu beberapa menit terakhir, filter:"
echo "       source.ip: 10.6.6.10 AND destination.ip: 172.16.6.10"
echo "   Harus muncul event ICMP. Screenshot layar itu, simpan ke:"
echo "       $AST/so-soc-icmp.png"
echo "   Itulah bukti 'Logging Check' yang diminta panduan (sisi SO, bukan host)."
