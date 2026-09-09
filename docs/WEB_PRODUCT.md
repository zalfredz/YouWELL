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

- **Daily Card Draw:** swipe deck berisi 5 kartu paket yang difilter berdasarkan
  jalur, difficulty, compliance, dan kondisi pengguna. Satu kartu berisi 3–5
  task; paket harus di-commit sebelum task dapat diselesaikan.
- **Today’s Tasks:** paket Daily Card, checklist, water reset, companion, serta
  reward/streak untuk aktivitas kecil saat berada di depan layar.
- **Focus & Craving:** reset tools berupa breathing circle, delay timer 5/10
  menit, soundscape, dan Micro-Vent; ringkasan ritme mingguan tetap tersedia.
- **Squad & Community:** progress squad serta encouragement wall read/react
  only; composer dan upload tetap khusus mobile.
- **Profile:** dibuka dari avatar kanan atas untuk melihat jalur, companion,
  dan data preview lokal. Ia tidak lagi menjadi menu sidebar.

## Prinsip interface

Web app menerapkan 8 Golden Rules pada keputusan yang terlihat pengguna:

1. token warna, label aksi, dan pola kartu yang konsisten;
2. landing/recap responsif, ukuran tombol yang nyaman, serta prompt khusus
   ketika workspace dibuka dari layar kecil;
3. feedback langsung melalui status kartu, snackbar, dan status antrean;
4. aksi selesai dengan pesan hasil yang jelas;
5. kartu yang belum di-commit tidak dapat keliru ditandai selesai;
6. status available, committed, dan completed selalu tampil pada kartu;
7. audio, timer, reaksi, dan navigasi selalu dimulai oleh pengguna;
8. kategori, tempat menyelesaikan kartu, dan status tampil pada konteks yang sama.

## Mode preview lokal

Tombol **Join Us!** langsung membuka web app tanpa login. Data demo disimpan
lokal pada browser agar fitur dapat diuji cepat. Route `/admin` membuka preview
**Community Admin** lokal untuk mengevaluasi alur moderasi.

Saat tahap backend dimulai, fitur yang perlu ditambahkan adalah:

1. autentikasi dan role `user`, `moderator`, `admin`; role menentukan apakah
   menu Community Admin tampil;
2. RLS untuk post, reaction, report, dan data recap;
3. status post `pending`, `approved`, `rejected`, dan `removed`;
4. token recap acak yang dapat kedaluwarsa atau dicabut;
5. audit log keputusan moderator melalui server/Edge Function.

Integrasi backend nanti harus menjaga data web dan mobile tetap konsisten tanpa
menaruh credential rahasia pada build Flutter web.
