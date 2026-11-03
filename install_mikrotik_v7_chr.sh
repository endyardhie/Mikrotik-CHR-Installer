#!/bin/bash
# Auto-Installer MikroTik CHR v7 untuk Ubuntu Server VPS
# Mendukung instalasi otomatis, injeksi IP, deteksi netmask, gateway, dan disk cerdas via fdisk offset.

echo "================================================="
echo "  MikroTik CHR v7 Auto Installer (Ubuntu VPS)    "
echo "================================================="

# Pastikan script dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "[-] Script ini harus dijalankan sebagai root (gunakan sudo)."
  exit 1
fi

# 1. Mendapatkan versi stable v7 terbaru
echo "[*] Mengecek versi terbaru MikroTik CHR v7 stable..."
VERSION=$(curl -s https://download.mikrotik.com/routeros/LATEST.7 | awk '{print $1}')
if [ -z "$VERSION" ]; then
    echo "[-] Gagal mendapatkan versi dari MikroTik. Set default ke 7.15.3"
    VERSION="7.15.3"
fi
echo "[+] Versi yang akan diinstall: $VERSION"

# 2. Deteksi Network (IP, Subnet/CIDR, Gateway)
echo "[*] Mendeteksi konfigurasi jaringan..."
INTERFACE=$(ip route show default | awk '/default/ {print $5}' | head -n 1)
if [ -z "$INTERFACE" ]; then
    echo "[-] Gagal mendeteksi interface network. Keluar."
    exit 1
fi

IP_CIDR=$(ip addr show $INTERFACE | grep -w 'inet' | awk '{print $2}' | head -n 1)
GATEWAY=$(ip route show default | awk '/default/ {print $3}' | head -n 1)

if [ -z "$IP_CIDR" ] || [ -z "$GATEWAY" ]; then
    echo "[-] Gagal mendeteksi IP atau Gateway secara otomatis. Keluar."
    exit 1
fi

echo "[+] Interface : $INTERFACE"
echo "[+] IP / CIDR : $IP_CIDR"
echo "[+] Gateway   : $GATEWAY"

# 3. Deteksi Disk Induk secara Akurat
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

# 4. Download & Ekstrak Image
echo "[*] Menyiapkan dependensi dan mengunduh image..."
apt-get update -y > /dev/null 2>&1
apt-get install -y curl wget unzip fdisk > /dev/null 2>&1

URL="https://download.mikrotik.com/routeros/$VERSION/chr-$VERSION.img.zip"
if ! wget -qO chr.img.zip "$URL"; then
    echo "[-] Gagal mengunduh file image MikroTik. Keluar."
    exit 1
fi

echo "[*] Mengekstrak file img..."
unzip -o chr.img.zip > /dev/null 2>&1
IMG_FILE="chr-$VERSION.img"

# 5. Mount image via kalkulasi offset (fdisk)
echo "[*] Menyuntikkan konfigurasi IP ke dalam image MikroTik..."
mkdir -p /mnt/chr

# Mencari start sector dari partisi ke-2
START_SECTOR=$(fdisk -l $IMG_FILE | grep -E "${IMG_FILE}2|img2" | awk '{print $2}')
if [ "$START_SECTOR" == "*" ]; then
    START_SECTOR=$(fdisk -l $IMG_FILE | grep -E "${IMG_FILE}2|img2" | awk '{print $3}')
fi

if [ -z "$START_SECTOR" ] || ! [[ "$START_SECTOR" =~ ^[0-9]+$ ]]; then
    echo "[-] Gagal mendapatkan offset sector dari image. Keluar."
    exit 1
fi

START_BYTE=$((START_SECTOR * 512))
echo "[+] Offset partisi 2 ditemukan di byte: $START_BYTE"

# Mount image secara langsung menggunakan kalkulasi offset byte
if ! mount -o loop,offset=$START_BYTE $IMG_FILE /mnt/chr; then
    echo "[-] Gagal mount partisi image menggunakan offset. Keluar."
    exit 1
fi

# Menyusun skrip otomatis RouterOS
mkdir -p /mnt/chr/rw
cat <<EOF > /mnt/chr/rw/autorun.scr
/ip address add address=$IP_CIDR interface=ether1
/ip route add gateway=$GATEWAY
EOF

umount /mnt/chr
echo "[+] Konfigurasi jaringan berhasil disuntikkan."

# 6. Menulis ke Disk dan Reboot
echo "[*] PERINGATAN: OS Ubuntu saat ini akan ditimpa dengan RouterOS!"
echo "[*] Menulis image ke $DISK_PATH (harap tunggu)..."

# Mengizinkan Magic SysRq untuk fast reboot
echo 1 > /proc/sys/kernel/sysrq

# Timpa disk dengan file image
dd if=$IMG_FILE of=$DISK_PATH bs=4M oflag=sync

echo "[*] Instalasi selesai. Server akan sync data dan memutus koneksi lalu reboot dalam 5 detik..."
sleep 5

# Memaksa kernel melakukan sinkronisasi disk dan reboot instan
echo s > /proc/sysrq-trigger
echo u > /proc/sysrq-trigger
echo b > /proc/sysrq-trigger
