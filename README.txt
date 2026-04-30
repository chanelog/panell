╔══════════════════════════════════════════════════════════════════╗
║          SCRIPT PREMIUM ST A1 NYEL - PETUNJUK INSTALL           ║
║                     Versi: GRATIS KITA                          ║
╚══════════════════════════════════════════════════════════════════╝

══════════════════════════════════════════════
  CARA INSTALL KE VPS
══════════════════════════════════════════════

1. Upload file menu.sh ke VPS Anda via SCP:
   scp menu.sh root@IP_VPS:/root/menu.sh

2. Beri izin eksekusi:
   chmod +x /root/menu.sh

3. Jalankan script:
   bash /root/menu.sh

4. Script akan otomatis install semua dependencies
   dari GitHub saat pertama kali dijalankan.

══════════════════════════════════════════════
  BINARY YANG DIINSTALL OTOMATIS
══════════════════════════════════════════════

[1] Xray-core
    Repo   : github.com/XTLS/Xray-core
    Versi  : Latest (auto-detect)
    Path   : /usr/local/bin/xray
    Fungsi : Protocol Vmess, Vless, Trojan, SS over WS/gRPC/TLS

[2] NoobzVPN Server
    Repo   : github.com/noobz-id/noobzvpns
    Install: Via installer resmi (install.sh)
    Fungsi : VPN tunnel alternatif SSH

[3] UDP Custom (ePro Dev)
    Repo   : github.com/Haris131/UDP-Custom
    Binary : udp-custom-linux-amd64
    Config : /root/udp/config.json
    Port   : 36712 (default)
    Fungsi : UDP tunnel untuk HTTP Custom / HA Tunnel

[4] Gotop
    Repo   : github.com/xxxserxxx/gotop
    Versi  : v4.2.0 (atau latest)
    Path   : /usr/local/bin/gotop
    Fungsi : Monitor RAM/CPU/Network real-time di terminal

[5] Speedtest-CLI
    Repo   : github.com/sivel/speedtest-cli
    File   : speedtest.py (Python script)
    Path   : /usr/local/bin/speedtest-cli
    Fungsi : Test kecepatan download/upload VPS

══════════════════════════════════════════════
  FITUR MENU (21 MENU)
══════════════════════════════════════════════

[01] SSH MENU        - Tambah/Hapus/Perpanjang/Lock akun SSH
[02] VMESS MENU      - Manajemen akun Vmess + generate link
[03] VLESS MENU      - Manajemen akun Vless + generate link
[04] TROJAN MENU     - Manajemen akun Trojan + generate link
[05] AKUN NOOBZVPN   - Manajemen akun NoobzVPN
[06] SS - LIBEV      - Manajemen akun Shadowsocks
[07] INSTALL UDP     - Install UDP Custom ePro Dev dari GitHub
[08] BCKP/RSTR       - Backup & Restore semua konfigurasi
[09] GOTOP X RAM     - Monitor resource VPS real-time
[10] RESTART ALL     - Restart semua service sekaligus
[11] TELE BOT        - Setup Telegram Bot notifikasi
[12] UPDATE MENU     - Update script dari GitHub
[13] RUNNING         - Cek status & proses yang berjalan
[14] INFO PORT       - Lihat semua port yang aktif
[15] MENU BOT        - Bot auto notif login + auto delete expired
[16] CHANGE DOMAIN   - Ganti domain VPS
[17] FIX CRT DOMAIN  - Perbarui sertifikat SSL Let's Encrypt
[18] CANGE BANNER    - Ubah banner/MOTD SSH
[19] RESTART BANNER  - Reset banner ke default
[20] SPEEDTEST       - Test kecepatan VPS dari GitHub
[21] EKSTRAK MENU    - Export akun & generate config Xray

══════════════════════════════════════════════
  STRUKTUR FILE DATA AKUN
══════════════════════════════════════════════

/etc/vmess/akun.txt          → username|uuid|expired
/etc/vless/akun.txt          → username|uuid|expired
/etc/trojan/akun.txt         → username|password|expired
/etc/shadowsocks/akun.txt    → username|password|expired
/etc/xray/domain             → nama domain VPS
/root/udp/config.json        → konfigurasi UDP Custom
/root/.bot_token             → token Telegram Bot
/root/.chat_id               → chat ID Telegram

══════════════════════════════════════════════
  KEBUTUHAN SISTEM
══════════════════════════════════════════════

OS        : Ubuntu 18.04 / 20.04 / 22.04 LTS (rekomendasi)
RAM       : Minimal 512 MB
Arsitektur: x86_64 (amd64) / aarch64 (arm64)
Akses     : Root / sudo
Internet  : Diperlukan untuk install dependencies

══════════════════════════════════════════════
  CATATAN PENTING
══════════════════════════════════════════════

- Script harus dijalankan sebagai ROOT
- Auto-install hanya berjalan SEKALI (ditandai /tmp/.st_a1_nyel_done)
- Untuk paksa install ulang: rm /tmp/.st_a1_nyel_done lalu jalankan lagi
- Domain harus diarahkan ke IP VPS sebelum request SSL (menu 17)
- Telegram Bot: dapatkan token dari @BotFather di Telegram

══════════════════════════════════════════════
  TROUBLESHOOTING
══════════════════════════════════════════════

Q: UDP Custom tidak bisa download?
A: Cek koneksi VPS ke GitHub, atau download manual:
   wget https://github.com/Haris131/UDP-Custom/raw/main/udp-custom-linux-amd64
   -O /root/udp/udp-custom && chmod +x /root/udp/udp-custom

Q: NoobzVPN tidak terinstall?
A: Install manual:
   wget -q https://github.com/noobz-id/noobzvpns/raw/main/install.sh
   bash install.sh

Q: Xray tidak berjalan?
A: Cek config: cat /etc/xray/config.json
   Start manual: systemctl start xray
   Lihat log: journalctl -u xray -n 50

Q: Gotop tidak ada?
A: Fallback ke htop: apt install htop

══════════════════════════════════════════════
  CREDIT
══════════════════════════════════════════════

Script by  : St A1 Nyel Team
Binary by  : XTLS, noobz-id, Haris131 (ePro Dev), xxxserxxx, sivel
Versi      : GRATIS KITA

══════════════════════════════════════════════
