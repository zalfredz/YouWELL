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

- **Hari ini:** melihat 3–5 Gacha Task dan menyelesaikan task nonfisik.
  Gerak serta catatan nutrisi diarahkan ke mobile.
- **Relief Room:** breathing circle, timer 5/10 menit, serta soundscape lokal.
- **Insights:** compliance, streak, companion, dan pintu ke Wrapped.
- **Komunitas:** membaca encouragement wall dan memberi reaksi cepat; tidak ada
  composer atau upload dari web.

## Batas preview lokal

Tombol `Coba web workspace` membuat profil `web_guest` di browser. Ini bukan
login atau akun produksi. Route `/admin` juga hanya meninjau post yang tersimpan
di browser yang sama.

Ketika Supabase ditambahkan, implementasikan:

1. autentikasi dan role `user`, `moderator`, `admin`;
2. RLS untuk post, reaction, report, dan data recap;
3. status post `pending`, `approved`, `rejected`, dan `removed`;
4. token recap acak yang dapat kedaluwarsa atau dicabut;
5. audit log keputusan moderator melalui server/Edge Function.

Jangan pernah meletakkan service-role key di build Flutter web.
