# Keputusan produk YouWELL

Dokumen ini merangkum keputusan yang masih berlaku. Bagian historis dalam
spesifikasi lama dibaca sebagai arsip jika bertentangan dengan keputusan di sini.
Aturan misi lebih rinci ada di [CHALLENGE_SPEC.md](CHALLENGE_SPEC.md), alur
rokok/vape di [REDUCTION_UAT.md](REDUCTION_UAT.md), dan setup server di
[SUPABASE_SETUP.md](SUPABASE_SETUP.md).

## 27 Oktober 2026 — progres dan data riset

- Total rokok dan vape per hari disimpan terpisah, disinkronkan sebagai angka
  harian, dan dapat diekspor menurut kode peserta P1–P10. Jam penggunaan,
  pemicu, kegiatan pengganti, hasil momen, dan catatan bebas tetap di perangkat.
- Admin ber-MFA dapat memulihkan progres peserta melalui Overview. Setiap
  intervensi memerlukan alasan, dicatat di log, dan ditandai pada progres serta
  ekspor penelitian. Server menyimpan 60 versi progres terakhir per akun.
- Perangkat yang belum pernah sinkron dengan akun tidak boleh menimpa progres
  cloud yang sudah ada.

## 23 Oktober 2026 — tidur, foto makan, dan kartu

- Level Tidur menggantikan misi layar off. Pada level 1–4, batas tidur berturut
  adalah 00.30, 00.00, 23.30, dan 23.00; batas bangun 07.30, 07.00, 06.30,
  dan 06.00. Waktu dicatat ketika tombol “Aku mau tidur” dan “Aku sudah bangun”
  ditekan. Jam mentah tetap di perangkat. Misi yang belum selesai dikonversi;
  riwayat selesai dan XP dipertahankan.
- Misi tambahan “Jeda layar” diganti “Jeda mikro”. Pilihan Santai/Normal dan
  jalan pintas rekomendasi di layar kartu dihapus; pengguna memilih langsung
  dari lima kartu.
- Foto Meal Snap diunggah sementara ke bucket privat untuk diperiksa admin
  ber-MFA. Setelah tiga jam tanpa keputusan, Edge Function meminta keputusan
  YA/TIDAK dari Gemini. Misi dan XP baru dihitung setelah foto disetujui,
  untuk hari foto diambil. Foto ditolak bisa diambil ulang. File foto di server
  dan perangkat dihapus setelah keputusan; status verifikasi tetap tersimpan.
  Foto lama dan pratinjau lokal tanpa server dihitung langsung.

## 20 dan 15 Oktober 2026 — periode studi dan Habit Swap

- Hanya 28 hari pertama masuk ringkasan studi. Setelah itu kartu, aktivitas,
  Habit Swap, dan catatan harian tetap dapat dipakai.
- Jalur rokok, vape, dan keduanya dibedakan sesuai pilihan pengguna. Persiapan
  pemicu dan kegiatan dilakukan per produk; kegiatan lain tetap bisa dipilih.
- Delay Craving dan timer dihapus dari alur aktif. Habit Swap tercatat setelah
  pengguna mencoba kegiatan pengganti. XP diberikan sekali per misi, terlepas
  dari apakah pengguna akhirnya merokok atau memakai vape. Setelah mencoba,
  pengguna memilih salah satu hasil; opsi “isi nanti” tidak lagi tersedia.
- Hasil satu momen tidak berarti bebas rokok/vape seharian. Hari tanpa
  penggunaan hanya berasal dari total harian nol yang dikonfirmasi. Hari tanpa
  catatan tidak dianggap nol.

## Batas data dan bahasa

- Foto Community mengikuti penyimpanan dan moderasi Community sendiri. Foto
  Meal Snap hanya diunggah sementara untuk verifikasi. Rute GPS, catatan
  bebas, jam tidur mentah, dan rincian momen Habit Swap tidak masuk snapshot
  progres cloud. Pengecualian untuk jalur rokok/vape hanya angka total harian.
- UI memakai bahasa Indonesia yang netral dan tidak menghakimi. Hindari label
  seperti “gagal”, “kambuh”, atau “pecandu”.
