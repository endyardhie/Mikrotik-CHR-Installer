#!/bin/bash
# Auto-Installer MikroTik CHR v6 untuk Ubuntu Server VPS (Manual IP via VNC)
# Mendukung instalasi otomatis dan deteksi disk cerdas. Konfigurasi IP dilakukan manual via VNC.

echo "================================================="
echo "  MikroTik CHR v6 Auto Installer (Ubuntu VPS)    "
echo "  Note: Konfigurasi IP harus dilakukan manual    "
echo "        melalui VNC Console setelah instalasi.   "
echo "================================================="

# Pastikan script dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "[-] Script ini harus dijalankan sebagai root (gunakan sudo)."
  exit 1
fi

# 1. Mendapatkan versi stable v6 terbaru
echo "[*] Mengecek versi terbaru MikroTik CHR v6 stable..."
VERSION=$(curl -s https://download.mikrotik.com/routeros/LATEST.6 | awk '{print $1}')
if [ -z "$VERSION" ]; then
    echo "[-] Gagal mendapatkan versi dari MikroTik. Set default ke 6.49.17"
    VERSION="6.49.17"
fi
echo "[+] Versi yang akan diinstall: $VERSION"

# 2. Deteksi Disk Induk secara Akurat
echo "[*] Mendeteksi disk instalasi..."
ROOT_PART=$(findmnt -n -o SOURCE /)
if [ -z "$ROOT_PART" ]; then
    echo "[-] Gagal mendeteksi partisi root. Keluar."
    exit 1
fi

DISK=$(lsblk -no PKNAME "$ROOT_PART")
if [ -z "$DISK" ]; then
    DISK=$(echo "$ROOT_PART" | sed -E 's/[0-9]+$//; s/p$//; s|/dev/||')
fi

DISK_PATH="/dev/$DISK"
echo "[+] Partisi Root : $ROOT_PART"
echo "[+] Disk target  : $DISK_PATH"

# 3. Download & Ekstrak Image
echo "[*] Menyiapkan dependensi dan mengunduh image..."
apt-get update -y > /dev/null 2>&1
apt-get install -y curl wget unzip > /dev/null 2>&1

URL="https://download.mikrotik.com/routeros/$VERSION/chr-$VERSION.img.zip"
if ! wget -qO chr.img.zip "$URL"; then
    echo "[-] Gagal mengunduh file image MikroTik. Keluar."
    exit 1
fi

echo "[*] Mengekstrak file img..."
unzip -o chr.img.zip > /dev/null 2>&1
IMG_FILE="chr-$VERSION.img"

# 4. Menulis ke Disk dan Reboot
echo "[*] PERINGATAN: OS Ubuntu saat ini akan ditimpa dengan RouterOS!"
echo "[*] Menulis image ke $DISK_PATH (harap tunggu)..."

# Mengizinkan Magic SysRq untuk fast reboot
echo 1 > /proc/sys/kernel/sysrq

# Timpa disk dengan file image
dd if=$IMG_FILE of=$DISK_PATH bs=4M oflag=sync

echo "[*] Instalasi selesai. Server akan memutus koneksi lalu reboot dalam 3 detik..."
echo "[!] Siapkan VNC Console dari provider VPS Anda untuk login dan setting IP."
sleep 3

# Memaksa kernel melakukan sinkronisasi disk dan reboot instan
echo s > /proc/sysrq-trigger
echo u > /proc/sysrq-trigger
echo b > /proc/sysrq-trigger
