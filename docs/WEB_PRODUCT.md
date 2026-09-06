# Produk web YouWell

Web bukan salinan aplikasi mobile. Ia terdiri dari tiga pengalaman yang jelas:
halaman publik, companion workspace untuk layar besar, dan alat moderasi.

## Rute

```text
/#/          Landing publik
/#/recap     Wrapped publik versi aman
/#/app       Workspace pengguna (desktop)
/#/admin     Dashboard moderator (desktop)
```

Landing dan recap bersifat responsif. Workspace dan admin menggunakan frame
16:9 di desktop; layar di bawah 860 px diberi prompt untuk kembali ke landing
atau memakai aplikasi mobile.

## Cakupan workspace

- **Hari ini:** melihat 3–5 **Gacha Cards** dan menyelesaikan task nonfisik.
  Gerak serta catatan nutrisi diarahkan ke mobile; kartu yang selesai dapat
  dibatalkan bila pengguna berubah pikiran.
- **Relief Room:** breathing circle, timer 5/10 menit, serta soundscape lokal.
- **Insights:** compliance, streak, companion, dan pintu ke Wrapped.
- **Komunitas:** membaca encouragement wall dan memberi reaksi cepat; tidak ada
  composer atau upload dari web.
- **Profil:** dibuka dari avatar kanan atas untuk melihat jalur, teman tumbuh,
  dan status sinkronisasi akun.

## Prinsip interface

Web app menerapkan 8 Golden Rules pada keputusan yang terlihat pengguna:

1. token warna, label aksi, dan pola kartu yang konsisten;
2. landing/recap responsif, ukuran tombol yang nyaman, serta prompt khusus
   ketika workspace dibuka dari layar kecil;
3. feedback langsung melalui status kartu, snackbar, dan status antrean;
4. aksi selesai dengan pesan hasil yang jelas;
5. aksi fisik/foto tidak dapat keliru ditandai dari web dan diarahkan ke mobile;
6. penyelesaian Gacha Card serta keputusan moderasi memiliki tombol **Batalkan**;
7. audio, timer, reaksi, dan navigasi selalu dimulai oleh pengguna;
8. kategori, tempat menyelesaikan kartu, dan status tampil pada konteks yang sama.

## Akses akun dan sinkronisasi

Tombol **Join Us!** membuka Google OAuth melalui Supabase. Setelah login,
aplikasi memuat snapshot milik akun tersebut dan memindahkan data lokal yang
ada pada perangkat ke snapshot pertama. Route `/admin` hanya menampilkan menu
**Community Admin** jika profile akun memiliki role `admin`.

Migration awal menyediakan profile role dan snapshot sinkronisasi. Tahap
berikutnya menambahkan tabel komunitas yang dinormalisasi untuk:

1. autentikasi dan role `user`, `moderator`, `admin`; role menentukan apakah
   menu Community Admin tampil;
2. RLS untuk post, reaction, report, dan data recap;
3. status post `pending`, `approved`, `rejected`, dan `removed`;
4. token recap acak yang dapat kedaluwarsa atau dicabut;
5. audit log keputusan moderator melalui server/Edge Function.

Dengan repository Supabase tersebut, aplikasi mobile dan YouWell Web App
membaca serta menyimpan Gacha Cards, profil, dan progres pengguna yang sama.
Penyimpanan browser hanya menjadi sumber data awal sebelum akun pertama masuk.

Jangan pernah meletakkan service-role key di build Flutter web.
