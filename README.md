# MikroTik CHR Installer (v6 & v7) untuk VPS

Script untuk memasang **MikroTik Cloud Hosted Router (CHR) v6 atau v7** pada VPS Ubuntu Server. Pengunduhan image, penulisan image ke disk, dan reboot dilakukan oleh script. **Konfigurasi jaringan setelah instalasi dilakukan secara manual melalui VNC Console atau konsol virtual provider VPS.**

Installer ini bukan instalasi tanpa intervensi sampai siap digunakan. Script tidak membuat `autorun.scr`, tidak memasukkan IP/gateway ke image RouterOS, dan tidak mengatur DNS, password, atau firewall. Jangan mengandalkan akses Winbox/SSH sebelum jaringan RouterOS selesai dikonfigurasi.

## Alur kerja script

Kedua script memiliki alur yang sama, dengan versi RouterOS yang berbeda:

1. Memeriksa bahwa script dijalankan sebagai `root`.
2. Membaca versi stable dari server MikroTik. Jika respons versi kosong, memakai versi fallback yang tertulis di script: **6.49.17** untuk v6 atau **7.15.3** untuk v7. Versi fallback tersebut bukan jaminan versi stable terbaru.
3. Mendeteksi interface default, alamat IPv4/CIDR pertama pada interface tersebut, dan default gateway Ubuntu; lalu menampilkannya di terminal. Script berhenti jika interface, IP/CIDR, atau gateway tidak terdeteksi.
4. Mencari perangkat root dengan `findmnt`, lalu menurunkan disk target menggunakan `lsblk` dan fallback nama perangkat. Disk target tidak terbatas pada nama `/dev/sda` atau `/dev/vda`, tetapi hasil deteksinya tetap harus diperiksa.
5. Menjalankan persiapan paket dengan `apt-get`, mengunduh image CHR `.img.zip`, dan mengekstraknya.
6. Menulis image ke disk target menggunakan `dd`.
7. Menampilkan dua perintah RouterOS untuk menambahkan IP dan gateway secara manual. **Perintah ini hanya dicetak, bukan dijalankan di RouterOS.**
8. Menunggu **5 detik**, lalu meminta sinkronisasi disk, remount read-only, dan reboot melalui Magic SysRq (`s`, `u`, `b`).

## Sebelum menjalankan installer

**Disk OS Ubuntu akan ditimpa image RouterOS. Data dan konfigurasi Ubuntu pada disk tersebut tidak dipertahankan.** Backup data penting dan siapkan opsi recovery/reinstall dari provider.

Pastikan prasyarat berikut terpenuhi:

- VPS dengan virtualisasi penuh, arsitektur x86-64, dan dukungan boot image CHR dari provider. Container seperti OpenVZ/LXC bukan target installer ini.
- Ubuntu Server dengan `apt-get` serta akses `root`/`sudo`.
- Koneksi internet ke GitHub, server unduhan MikroTik, dan repositori paket Ubuntu.
- `curl` sudah tersedia **sebelum** installer dijalankan, karena dipakai untuk mengunduh script dan mengecek versi sebelum tahap instalasi dependensi. Jika belum ada, jalankan `sudo apt-get update && sudo apt-get install -y curl` di Ubuntu terlebih dahulu.
- Perintah jaringan dan disk seperti `ip`, `findmnt`, dan `lsblk` tersedia. Susunan disk standar lebih mudah diverifikasi; jangan menganggap deteksi disk otomatis cocok untuk semua konfigurasi LVM, RAID, atau root filesystem khusus.
- Akses **VNC Console/konsol virtual dari panel provider** sudah tersedia dan telah dicoba. Pastikan konsol tersebut tetap dapat dipakai saat jaringan di dalam VPS belum aktif.

### Catat jaringan dan disk Ubuntu terlebih dahulu

Jalankan perintah berikut di Ubuntu untuk melihat konfigurasi yang sedang digunakan:

```bash
ip -4 address show
ip -4 route show
findmnt -n -o SOURCE /
lsblk
```

Simpan catatan **di luar VPS**: IP beserta prefix/CIDR, gateway, interface/MAC, DNS provider, dan disk OS. Cocokkan dengan pengaturan jaringan pada panel atau dokumentasi provider. Nama interface Ubuntu, misalnya `ens3`, belum tentu sama dengan nama interface di RouterOS.

Script hanya mengambil satu alamat IPv4 dan satu default gateway. Jika VPS memiliki beberapa IP, beberapa interface/default route, IPv6, jaringan NAT, atau gateway di luar subnet, simpan pula konfigurasi khusus dari provider; script tidak memigrasikan semuanya.

Perhatikan output awal `Interface`, `IP / CIDR`, `Gateway`, dan `Disk target`. **Tidak ada prompt konfirmasi sebelum `dd` menimpa disk.** Jangan lanjutkan bila hasil deteksi tidak sesuai. Dua perintah jaringan ditampilkan lagi menjelang reboot, tetapi waktu tunggunya hanya 5 detik; catat nilai jaringan sejak awal.

## Menjalankan installer

Jalankan **salah satu** perintah berikut dari terminal Ubuntu, sesuai versi RouterOS yang diinginkan. Perintah ini mengunduh dan langsung menjalankan script sebagai root; baca script yang dipilih terlebih dahulu.

### CHR v6

Sumber: [install_mikrotik_v6_chr.sh](install_mikrotik_v6_chr.sh)

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/endyardhie/Mikrotik-CHR-Installer/main/install_mikrotik_v6_chr.sh)"
```

### CHR v7

Sumber: [install_mikrotik_v7_chr.sh](install_mikrotik_v7_chr.sh)

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/endyardhie/Mikrotik-CHR-Installer/main/install_mikrotik_v7_chr.sh)"
```

Pantau proses sampai penulisan image selesai dan VPS reboot. Koneksi SSH Ubuntu akan terputus. Lama unduhan dan boot bergantung pada koneksi serta provider; gunakan konsol untuk melihat progres, bukan menganggap jeda waktu tertentu sebagai tanda instalasi berhasil.

## Konfigurasi manual setelah instalasi

### 1. Login melalui konsol provider

Buka VNC Console/konsol virtual dari panel provider dan tunggu prompt login RouterOS. Untuk image CHR baru, login awal menggunakan:

- **Username:** `admin`
- **Password:** kosong; tekan Enter.

Jika RouterOS meminta password baru saat login pertama, ikuti prompt tersebut. Password Ubuntu sebelumnya tidak menjadi password RouterOS.

### 2. Tetapkan password administrator

Lakukan sebelum membuka akses manajemen melalui jaringan. Jika belum diatur melalui prompt login pertama, jalankan dari terminal RouterOS:

```routeros
/user set [find name="admin"] password="GANTI_DENGAN_PASSWORD_KUAT_ANDA"
```

Ganti teks di dalam tanda kutip dengan password Anda sendiri. Jika password baru sudah ditetapkan lewat prompt login, tidak perlu menjalankan langkah ini lagi.

### 3. Periksa interface dan konfigurasi yang sudah ada

```routeros
/interface print
/ip address print
/ip route print
/ip dhcp-client print
```

Script mencetak perintah dengan asumsi interface RouterOS adalah **`ether1`**. Pastikan interface itu benar-benar terhubung ke jaringan provider; sesuaikan namanya bila berbeda. Jangan memakai nama interface Ubuntu secara langsung.

Jika sudah ada alamat atau default route, periksa asalnya terlebih dahulu agar tidak menambahkan konfigurasi duplikat. Jika provider mewajibkan DHCP, ikuti skema provider dan periksa DHCP client; contoh statis di bawah bukan pengganti aturan jaringan provider.

### 4. Tambahkan IP/CIDR dan default gateway

Gunakan **nilai nyata yang tercatat dari Ubuntu/provider**, atau salin dua perintah yang dicetak installer sebelum reboot. Bentuknya adalah:

```text
/ip address add interface=ether1 address=IP_CIDR_VPS
/ip route add gateway=GATEWAY_VPS
```

Ganti `IP_CIDR_VPS` dengan alamat beserta prefix, dan `GATEWAY_VPS` dengan gateway Anda. Jangan mengetik placeholder tersebut secara literal. Parameter `dst-address` yang tidak ditulis pada perintah route menggunakan default `0.0.0.0/0`.

Contoh pengisian berikut **hanya ilustrasi**, bukan IP yang boleh digunakan pada VPS Anda:

```routeros
/ip address add interface=ether1 address=203.0.113.10/24
/ip route add dst-address=0.0.0.0/0 gateway=203.0.113.1
```

**Khusus prefix `/32`, gateway di luar subnet, atau jaringan routed/point-to-point:** dua perintah umum dari installer mungkin belum cukup. Pertahankan prefix yang diberikan provider dan ikuti petunjuk RouterOS dari provider untuk menjangkau gateway (misalnya pengaturan network/host route yang sesuai). Jangan mengganti `/32` menjadi `/24` hanya agar gateway terlihat berada dalam subnet. Pastikan default route aktif sebelum beralih ke akses jarak jauh.

### 5. Atur DNS RouterOS

Script tidak menyalin DNS Ubuntu. Gunakan DNS yang diizinkan provider. Contoh berikut memakai resolver publik dan membatasi resolver RouterOS untuk kebutuhan router sendiri:

```routeros
/ip dns set servers=1.1.1.1,8.8.8.8 allow-remote-requests=no
```

### 6. Periksa konektivitas

```routeros
/ip address print
/ip route print detail
/ip dns print
/ping 1.1.1.1 count=4
/ping example.com count=4
```

Pastikan IP berada di interface yang benar dan route `0.0.0.0/0` aktif. Jika akses IP berhasil tetapi nama domain tidak dapat di-resolve, periksa DNS. Timeout ping saja tidak membuktikan jaringan putus karena ICMP dapat diblokir; cocokkan juga status route dan kebijakan provider.

### 7. Akses melalui Winbox atau SSH

Setelah jaringan dikonfigurasi:

1. Buka Winbox dan isi **Connect To** dengan IP publik VPS (atau alamat/port manajemen yang disediakan provider untuk VPS NAT).
2. Login sebagai `admin` dengan **password baru** yang telah ditetapkan melalui konsol.
3. Jika menggunakan SSH, hubungkan ke IP/port yang sesuai dengan user dan password RouterOS, bukan kredensial Ubuntu.

Periksa `/ip service print` jika layanan manajemen tidak dapat dijangkau. Cocokkan service aktif, port, pembatasan alamat, firewall RouterOS, dan firewall/security group provider. Batasi akses manajemen ke IP administrator yang diperlukan; script tidak membuat aturan firewall atau pembatasan akses untuk Anda.

## Jika belum bisa diakses

| Gejala | Yang perlu diperiksa |
| --- | --- |
| SSH terputus setelah instalasi | Normal saat reboot. Lanjutkan lewat konsol provider; IP/gateway RouterOS belum dikonfigurasi oleh installer. |
| RouterOS tidak muncul di konsol | Periksa status boot, disk target, kompatibilitas boot/disk/NIC CHR, serta opsi recovery provider. Jika masih tampil Ubuntu, proses penulisan/reboot belum berhasil. |
| Default route tidak aktif | Periksa gateway, prefix/CIDR, interface, dan kebutuhan route tambahan untuk jaringan `/32` atau gateway di luar subnet. |
| Internet dari router bekerja, tetapi Winbox/SSH gagal | Periksa layanan/port, firewall RouterOS dan provider, IP sumber yang diizinkan, serta port forwarding untuk VPS NAT. |
| IP terjangkau tetapi resolusi nama gagal | Periksa `/ip dns print`, server DNS yang digunakan, dan izin koneksi DNS dari router. |
| Koneksi SSH menampilkan perbedaan host key | OS telah diganti sehingga host key dapat berubah. Verifikasi VPS yang benar melalui konsol provider sebelum memperbarui catatan host key di komputer Anda. |

Jangan menjalankan installer lagi untuk memperbaiki IP/gateway. Perbaiki konfigurasi melalui konsol agar RouterOS tidak ditimpa ulang.

## Referensi

- Alur installer: [script v6](install_mikrotik_v6_chr.sh) dan [script v7](install_mikrotik_v7_chr.sh).
- [MikroTik CHR — kebutuhan virtualisasi dan login awal](https://help.mikrotik.com/docs/spaces/ROS/pages/18350234/Cloud+Hosted+Router+CHR).
- [MikroTik — konfigurasi awal RouterOS](https://manual.mikrotik.com/docs/getting-started/first-time-configuration/).
- [MikroTik — pengaturan DNS](https://help.mikrotik.com/docs/spaces/ROS/pages/37748767/DNS).

## Lisensi

Proyek ini menggunakan [MIT License](LICENSE).
