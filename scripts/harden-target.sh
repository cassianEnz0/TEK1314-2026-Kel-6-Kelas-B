#!/bin/sh
# Hardening dasar Target Node SRV-WEB-KEL06B (Metasploitable 2, Ubuntu 8.04).
# Jalankan sebagai root di target:  sudo sh harden-target.sh <password-webadmin>
#
# Yang dilakukan:
#   1. Identitas: hostname dan IP statis sesuai ip_plan.
#   2. Layanan: mematikan layanan di luar lingkup skenario.
#   3. Akun: admin non-root "webadmin", root dan akun tak terpakai tidak bisa SSH.
#   4. Firewall: iptables default DROP, hanya port lingkup serangan yang dibuka.
#
# Port yang sengaja tetap dibuka untuk segmen Attacker (lingkup fase 2):
#   21 (vsftpd 2.3.4), 80 (Apache: DVWA, Mutillidae, phpMyAdmin), 8180 (Tomcat).
# Port 22 hanya untuk administrasi dari segmen Monitoring dan router.
set -e

WEBADMIN_PASS="$1"
if [ -z "$WEBADMIN_PASS" ]; then
    echo "Pemakaian: sudo sh $0 <password-webadmin>" >&2
    exit 1
fi

HOSTNAME_BARU=SRV-WEB-KEL06B
IP=172.16.6.10
NETMASK=255.255.255.0
GW=172.16.6.1
NET_ATTACKER=10.6.6.0/24
NET_MGMT=192.168.6.0/24
ROUTER=172.16.6.1
PORT_SERANGAN=21,80,8180

echo "== 1. Identitas"
echo "$HOSTNAME_BARU" > /etc/hostname
hostname "$HOSTNAME_BARU"
sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$HOSTNAME_BARU/" /etc/hosts
# Zona waktu disamakan dengan host supaya timestamp mudah dicocokkan dengan
# log Security Onion. tzdata 2008 masih menamai Asia/Jakarta "WIT".
echo Asia/Jakarta > /etc/timezone
cp /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

cat > /etc/network/interfaces <<EOF
# The loopback network interface
auto lo
iface lo inet loopback

# Segmen Target (172.16.6.0/24), gateway router G0/1
auto eth0
iface eth0 inet static
    address $IP
    netmask $NETMASK
    gateway $GW
    pre-up iptables-restore < /etc/iptables.rules
    pre-up ip6tables-restore < /etc/ip6tables.rules || true
EOF

echo "== 2. Layanan di luar lingkup"
# Dimatikan sekarang dan dicabut dari urutan boot.
# Aktifkan lagi (kalau fase 2 butuh) dengan: update-rc.d <nama> defaults
for svc in bind9 distcc mysql-ndb mysql-ndb-mgm nfs-kernel-server nfs-common \
           portmap postfix postgresql-8.3 proftpd rsync samba openbsd-inetd; do
    if [ -x /etc/init.d/$svc ]; then
        /etc/init.d/$svc stop || true
        update-rc.d -f $svc remove
    fi
done

# inetd.conf berisi telnet, tftp, rsh, rlogin, rexec, dan bindshell root di
# port 1524 (ingreslock). Semua dinonaktifkan, xinetd tinggal melayani vsftpd.
[ -f /etc/inetd.conf.asli ] || cp /etc/inetd.conf /etc/inetd.conf.asli
sed -i 's/^\([^#]\)/#\1/' /etc/inetd.conf

# rc.local menjalankan rmiregistry (1099), UnrealIRCd (6667/6697),
# VNC (5900/6000), dan druby (8787). Semuanya dihapus dari rc.local.
[ -f /etc/rc.local.asli ] || cp /etc/rc.local /etc/rc.local.asli
cat > /etc/rc.local <<'EOF'
#!/bin/sh -e
# Layanan bawaan Metasploitable (rmiregistry, unrealircd, vncserver, druby)
# sengaja tidak dijalankan. Salinan asli: /etc/rc.local.asli
modprobe nf_conntrack_ftp 2>/dev/null || true
exit 0
EOF
pkill -f rmiregistry || true
pkill -f unrealircd || true
pkill -f Xtightvnc || true
pkill -f druby_timeserver || true
/etc/init.d/xinetd restart

echo "== 3. Akun"
if ! id webadmin >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G admin webadmin
fi
echo "webadmin:$WEBADMIN_PASS" | chpasswd
# Akun bawaan yang tidak dipakai untuk administrasi dikunci.
passwd -l user
passwd -l service

[ -f /etc/ssh/sshd_config.asli ] || cp /etc/ssh/sshd_config /etc/ssh/sshd_config.asli
sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
grep -q '^AllowUsers' /etc/ssh/sshd_config \
    && sed -i 's/^AllowUsers .*/AllowUsers webadmin/' /etc/ssh/sshd_config \
    || echo 'AllowUsers webadmin' >> /etc/ssh/sshd_config
/etc/init.d/ssh restart

echo "== 4. Firewall"
modprobe nf_conntrack_ftp 2>/dev/null || true
cat > /etc/iptables.rules <<EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p icmp --icmp-type echo-request -s $NET_ATTACKER -j ACCEPT
-A INPUT -p icmp --icmp-type echo-request -s $NET_MGMT -j ACCEPT
-A INPUT -p icmp --icmp-type echo-request -s $ROUTER -j ACCEPT
-A INPUT -p tcp -s $NET_ATTACKER -m multiport --dports $PORT_SERANGAN -m state --state NEW -j ACCEPT
-A INPUT -p tcp -s $NET_MGMT --dport 22 -m state --state NEW -j ACCEPT
-A INPUT -p tcp -s $ROUTER --dport 22 -m state --state NEW -j ACCEPT
-A INPUT -m limit --limit 5/min -j LOG --log-prefix "IPT-DROP "
COMMIT
EOF
cat > /etc/ip6tables.rules <<EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
COMMIT
EOF
iptables-restore < /etc/iptables.rules
ip6tables-restore < /etc/ip6tables.rules || echo "ip6tables tidak tersedia, dilewati"

echo "== Selesai. Reboot untuk menguji konfigurasi permanen."
