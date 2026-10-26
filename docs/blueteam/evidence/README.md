# Bukti Hardening (before/after)

Screenshot diambil langsung dari konsol terminal VM target (172.16.6.10), kondisi
sebelum hardening (snapshot rapuh) dan sesudah (snapshot hardened).

| Kontrol | Before | After | Yang dibuktikan |
|---|---|---|---|
| A1 PermitRootLogin | A1_root_login_before.png | A1_root_login_after.png | root login via SSH: default -> `permitrootlogin no` |
| A2 SSH key-only | A2_ssh_password_before.png | A2_ssh_password_after.png | password SSH: `yes` -> `no` (config efektif `sshd -T`) |
| A3 fail2ban | A3_fail2ban_before.png | A3_fail2ban_after.png | fail2ban: inactive -> active, jail sshd jalan |
| A4 kredensial default dashboard | A4_default_cred_before.png | A4_default_cred_after.png | login default: HTTP 307 diterima -> 401 ditolak |
| B1 firewall UFW | B1_ufw_before.png | B1_ufw_after.png | UFW: inactive -> deny incoming, hanya 8000 + SSH dari mgmt |
| B2 DB bind loopback | B2_db_binding_before.png | B2_db_binding_after.png | pooler 5432/6543: `0.0.0.0` -> `127.0.0.1` |
| B4 matikan service | B4_disable_service_before.png | B4_disable_service_after.png | realtime dan functions: running -> tidak jalan |
| C1 Row Level Security | C1_rls_before.png | C1_rls_after.png | RLS: `f` -> `t`; anon baca profiles: HTTP 200 -> 401 |

Bukti tambahan:
- `s1-nmap-before.txt`, `s1-nmap-after.txt`: nmap port terbuka, dari 22/5432/6543/8000 menjadi 22/8000 (bukti B1 dan B2 dari sisi luar).
- `s2-exfil-before.json`, `s2-exfil-after.json`: eksfiltrasi anon, dari data tumpah menjadi 401 (bukti C1).
- `s3-brute-before.txt`, `s3-brute-after.txt`: kredensial default, dari diterima menjadi 401 (bukti A4).
- `SO_deteksi.png`: Security Onion mencatat trafik ke target (Zeek conn dan alert Suricata), bukti monitoring aktif.

Catatan: config SSH diverifikasi dengan `sudo sshd -T` (config efektif gabungan),
bukan sekadar isi satu file, karena setting bisa tersebar di beberapa berkas drop-in.
