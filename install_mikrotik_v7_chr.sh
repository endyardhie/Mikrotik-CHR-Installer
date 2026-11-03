#!/bin/bash
# Auto-Installer MikroTik CHR v7 untuk Ubuntu Server VPS
# Mendukung instalasi otomatis, injeksi IP, deteksi netmask dan gateway.

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
VERSION=$(curl -s https://download.mikrotik.com/routeros/LATEST.7)
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

# 3. Deteksi Disk (sda / vda)
echo "[*] Mendeteksi disk instalasi..."
DISK=$(lsblk -nd -o NAME | grep -E '^vda|^sda' | head -n 1)
if [ -z "$DISK" ]; then
    echo "[-] Tidak ada disk sda atau vda yang ditemukan. Keluar."
    exit 1
fi
DISK_PATH="/dev/$DISK"
echo "[+] Disk target : $DISK_PATH"

# 4. Download & Ekstrak Image
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

# 5. Mount image via loop device dan injeksi IP (autorun.scr)
# Menyuntikkan IP ke dalam sistem file CHR agar VPS tidak terputus dari jaringan setelah reboot.
echo "[*] Menyuntikkan konfigurasi IP ke dalam image MikroTik..."
LOOPDEV=$(losetup -f)
losetup -P $LOOPDEV $IMG_FILE

mkdir -p /mnt/chr
# CHR memiliki 2 partisi: p1 (boot), p2 (root/ext2 atau ext3)
if ! mount ${LOOPDEV}p2 /mnt/chr; then
    echo "[-] Gagal mount partisi image. Pastikan kernel mendukung loop partition."
    losetup -d $LOOPDEV
    exit 1
fi

# Menyusun skrip otomatis RouterOS
mkdir -p /mnt/chr/rw
cat <<EOF > /mnt/chr/rw/autorun.scr
/ip address add address=$IP_CIDR interface=ether1
/ip route add gateway=$GATEWAY
EOF

umount /mnt/chr
losetup -d $LOOPDEV
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
