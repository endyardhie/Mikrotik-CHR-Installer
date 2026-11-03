MikroTik CHR Auto Installer (v6 & v7) for VPS

Script otomatis untuk menginstal MikroTik Cloud Hosted Router (CHR) versi v6 (Stable) dan v7 (Stable) pada Virtual Private Server (VPS) ber-OS Ubuntu Server.

Script ini dirancang untuk berjalan secara fully-automated (tanpa intervensi manual setelah dijalankan), sangat cocok untuk VPS berbasis cloud (KVM, OpenVZ, Xen, dll) seperti DigitalOcean, Linode, Vultr, Biznet Gio, Hetzner, dan provider lainnya.

🚀 Fitur Utama

Pengecekan Versi Otomatis: Mendeteksi dan mengunduh versi Stable v6 atau v7 terbaru secara langsung dari server resmi MikroTik (download.mikrotik.com).

Auto Detect Network: Mendeteksi secara otomatis Interface, IP Address, Subnet Mask / CIDR, dan Default Gateway dari VPS Ubuntu Anda.

Auto Detect Storage Disk: Mendeteksi otomatis disk target utama (/dev/sda atau /dev/vda).

IP Auto Injection: Menyuntikkan konfigurasi jaringan ke dalam file autorun.scr pada image RouterOS sebelum penulisan ke disk, sehingga VPS langsung terhubung ke internet dan dapat diakses via Winbox/SSH setelah reboot pertama.

Force Reboot Safe Sync: Menggunakan kernel Magic SysRq trigger untuk memastikan penulisan disk disinkronkan dan memicu reboot instan tanpa hang.

⚠️ Perhatian (Disclaimer)

Kehilangan Data: Script ini akan menghapus penuh (wipe/overwrite) seluruh isi disk OS Ubuntu Anda dan menggantinya dengan MikroTik CHR.

Backup: Pastikan tidak ada data penting yang tertinggal di VPS Ubuntu Anda sebelum menjalankan script ini.

Kredensial Default MikroTik:

Username: admin

Password: (kosongkan / tanpa password)

📋 Prasyarat

OS: Ubuntu Server (18.04 / 20.04 / 22.04 / 24.04 LTS).

Akses: Memiliki akses root atau sudo.

Tipe Disk: Menggunakan disk berbasis /dev/sda atau /dev/vda.

🛠️ Cara Penggunaan (One-Line Command)

Jalankan salah satu perintah di bawah ini pada terminal VPS Ubuntu Anda (sesuai versi RouterOS yang Anda inginkan).

Catatan: Ganti USERNAME dengan username GitHub Anda sendiri.

Instal MikroTik CHR v6 (Stable)

sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/endyardhie/mikrotik-chr-installer/main/install_mikrotik_v6_chr.sh)"


Instal MikroTik CHR v7 (Stable)

sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/endyardhie/mikrotik-chr-installer/main/install_mikrotik_v7_chr.sh)"


🔧 Langkah setelah Instalasi

Tunggu 1 - 3 menit hingga proses instalasi dan reboot di sisi server selesai.

Buka aplikasi Winbox.

Masukkan IP Address VPS Anda pada kolom Connect To:.

Masukkan Username: admin, Password: (kosong).

Klik Connect.

Jangan lupa untuk segera mengganti password admin default Anda demi keamanan:

/user set admin password=PASSWORD_BARU_ANDA


📄 Lisensi

Proyek ini menggunakan lisensi MIT License.
