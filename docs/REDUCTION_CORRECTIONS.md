# Persiapan koreksi konsumsi dan Habit Swap

Status: alat preview dan migration kompatibilitas disiapkan lokal. Tidak ada
kredensial, koneksi database produksi, atau penulisan data otomatis di alat ini.
Angka peserta disimpan di `.tools/reduction-import/` yang diabaikan Git.

## Hasil analisis

- P5/P6/P7 mengikuti R1/R2/R3 (batang rokok); P8/P9/P10 mengikuti V1/V2/V3
  (sesi vape). Pengelola menyatakan angka sumber sebagai koreksi catatan nyata.
- Hari pertama mengikuti `study_started` yang dikunci per akun, dengan
  `profile.started` hanya sebagai fallback. Urutan sumber dipakai sebagai hari
  studi 1–28, bukan memindahkan tanggal mulai supaya cocok dengan Senin.
- Potong hingga hari studi yang sudah dicapai pada tanggal pemeriksaan,
  maksimum 28. Tidak ada pembuatan tanggal, aktivitas, atau quest masa depan.
- Semua 168 nilai konsumsi dan 24 total mingguan Habit Swap sumber cocok.
  Batas maksimum rokok 15 hanya aturan dataset ini, bukan batas server semua
  pengguna. Definisi sesi vape tiga menit pada sumber perlu tetap dibedakan
  dari versi pengukuran lain; jangan mengonversi sesi ke batang atau dosis.
- Jumlah mencoba Habit Swap bukan log membuka halaman. `skipped` berarti
  tidak jadi memakai pada momen itu; `used` berarti tetap memakai. Tidak ada
  timestamp, pemicu, aktivitas, atau hasil yang boleh direka dari jumlah ini.
- Detail Habit Swap di cloud membawa `id` dan `day`. Update GitHub tanggal
  6 November menambahkan `swapResults` (tahap 13–14): jumlah mencoba, tidak
  jadi, dan tetap memakai per tanggal/produk, dengan penanda admin. Preview
  kini menghasilkan usulan `swapResults` tanpa jam, pemicu, atau kegiatan.
  Server target perlu migration tersebut sebelum usulan dapat disimpan.
- Catatan konsumsi tidak membuktikan aplikasi dibuka. `openedDays` dan
  `adminOpenedDays` tetap utuh sampai catatan pembukaan aplikasi dikonfirmasi.

## Preview menurut akun yang sebenarnya

1. Jalankan query **read-only** `scripts/reduction-correction-preflight.sql`
   di SQL Editor project yang benar. Simpan nilai JSON `overview` ke
   `.tools/reduction-import/overview.json`. Simpan lokal, jangan commit.
2. Cocokkan enam kode dan tanggal mulai. Query tidak mengembalikan email,
   Google identity, atau key; snapshot tetap data privat peserta.
3. Jalankan, dengan tanggal pemeriksaan yang benar di Asia/Jakarta:

```powershell
node scripts/prepare-reduction-corrections.cjs .tools/reduction-import/source.json .tools/reduction-import/overview.json 2026-11-08 .tools/reduction-import/preview.json
```

Preview mengandung pemetaan akun, revisi awal, hash snapshot, jumlah hari,
rincian harian, total mingguan, dan usulan `usageTotals`/`swapResults`. Tidak ada fungsi
yang mengirim hasil ini ke Supabase. Jika kode ambigu, akun ganda, tanggal
rusak, atau total harian berbeda dari total mingguan, preview berhenti.

Penulisan yang kelak dilakukan harus memakai revisi terbaru, mencadangkan
snapshot asli, mencatat alasan dan bukti koreksi, menjaga data di luar cakupan,
serta mengganti hitungan yang dikoreksi (bukan menambahkan hitungan dua kali).
Hasil yang tidak diketahui tetap kategori tersendiri, tidak dianggap berhasil.
Jangan menaikkan XP, membuat quest selesai, atau menandai login otomatis.

## Kompatibilitas versi lama

Migration tahap 15:
`supabase/migrations/20261108120000_legacy_progress_compatibility.sql`.
Jalankan setelah tahap 14; belum diterapkan otomatis ke project mana pun.

Perilaku adapter:

- Snapshot dengan `schemaVersion=1`, `version=3` memakai endpoint RPC yang
  sama. Field opsional yang hilang/null mendapat default; koleksi kosong yang
  dulu tersimpan sebagai bentuk map/list terbalik diperbaiki hanya bila kosong.
- Field top-level tak dikenal dan detail privat tidak disimpan. Profil
  diproyeksikan ke field yang dikenal. Payload mentah tetap harus dipertahankan
  di perangkat; adapter ini tidak memulihkan data lokal yang sudah hilang.
- `type=cigarette` diterjemahkan ke `rokok`; angka bulat dalam string yang
  jelas seperti `"7"` diterima. Tidak mengubah `501` menjadi `500`, membulatkan
  pecahan, mengarang konfirmasi, atau menggeser tanggal kalender yang rusak.
- Jika versi lama belum memiliki `usageTotals`, data cloud yang sudah ada
  dipertahankan. Total admin, tanda hari buka admin, dan momen `admin-...`
  dipertahankan terhadap unggahan lama yang kosong.
- `swapResults` dari tahap 13–14 tetap diterima. Agregat yang tidak dikirim
  versi lama serta hasil bertanda admin dipertahankan pada server.
- Koleksi opsional yang tidak dikirim versi lama dipertahankan dari cloud,
  bukan dikosongkan. Reset eksplisit dengan `profile: null` tetap menghapus
  progres seperti sebelumnya; kompatibilitas tidak membatalkan pilihan reset.
- Admin tetap membutuhkan allowlist + MFA, alasan, revisi terbaru, dan profil
  yang tidak berubah. Profil historis yang tidak sesuai perlu disinkronkan
  akun peserta dahulu; admin tidak diberi jalan pintas mengubah identitasnya.
- Isi koleksi yang tidak kosong tetapi rusak, schema yang tak dikenal, tanggal
  tak valid, jumlah negatif/pecahan/>500 tetap ditolak. Itu kerusakan data,
  bukan sekadar aplikasi lama. Jangan mematikan validator secara keseluruhan.

Tes lokal:

```powershell
node --test scripts/prepare-reduction-corrections.test.cjs
npm install --prefix .tools/sql-check --no-audit --no-fund @electric-sql/pglite
node scripts/check-supabase-migrations.cjs
```

Tes memakai fixture sintetis dan PostgreSQL dalam memori, tanpa akun produksi.
Tidak membuktikan versi APK tertentu bekerja sebelum dites dengan payload
aslinya, dan tidak membuktikan migrasi sudah terpasang di Supabase remote.
