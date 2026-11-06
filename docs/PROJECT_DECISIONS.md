# Keputusan produk YouWELL

Dokumen ini merangkum keputusan yang masih berlaku. Bagian historis dalam
spesifikasi lama dibaca sebagai arsip jika bertentangan dengan keputusan di sini.
Aturan misi lebih rinci ada di [CHALLENGE_SPEC.md](CHALLENGE_SPEC.md), alur
rokok/vape di [REDUCTION_UAT.md](REDUCTION_UAT.md), dan setup server di
[SUPABASE_SETUP.md](SUPABASE_SETUP.md).

## 6 November 2026 — dashboard peneliti sebagai laporan week

- Week = 7 hari sejak peserta mulai (Week 1 = hari 1–7), bukan minggu
  kalender. Tab Analisis studi tersusun sebagai laporan: temuan utama yang
  disusun otomatis, tabel metrik × Week 1–4 (n di setiap angka), grafik per
  metrik, progres per peserta per week, dan rokok/vape per peserta.
- "Cek perubahan konsumsi" membandingkan rata-rata rokok/vape Week 1 dengan
  week selesai terakhir yang punya minimal 4 hari tercatat, per produk:
  turun ≥ 50%, turun 20–49%, stabil (±20%), naik > 20%, atau data belum
  cukup; ditambah hari dengan total 0, tren harian (minimal 8 hari tercatat),
  dan median perubahan kelompok. Ini perubahan selama pemakaian, bukan uji
  efektivitas (Week 1 sudah masa pemakaian, tanpa pembanding, laporan diri).
- Angka kelompok hanya memakai week yang sudah selesai; week yang belum
  selesai tertulis "berjalan". Tombol "Salin untuk slide" dan "Unduh tabel
  week (CSV)" memakai angka yang sama dengan tabel di layar.

## 4 November 2026 — Istirahat menjadi Hibernasi

- Mulai 5 November level Istirahat (kunci `Energy`, kolom `tangga_istirahat`)
  berisi **Hibernasi 1/2/3/5 menit**: hitung mundur napas tenang (tarik 4,
  hembuskan 6) lalu berdiam. Misi tercentang otomatis saat hitung mundur
  selesai; berhenti di tengah tidak memberi XP. Waktu dihitung dari jam mulai.
- Misi tidur yang masih terbuka di hari ≥ 5 Nov diganti Hibernasi pada level
  yang sama; misi tidur 4 Nov dan sebelumnya tetap dinilai sebagai tidur.
  Riwayat, XP, dan level tidak berubah. Kartu "Siap tidur?" di Beranda
  dihapus; check-in yang masih terbuka tetap bisa ditutup.
- Isi `tangga_istirahat` berbeda per periode: layar off (s.d. 22 Okt), tidur
  (23 Okt–4 Nov), Hibernasi (mulai 5 Nov). Dashboard memberi penanda 5 Nov.
- Aturan "kartu tanpa misi tidur berisi 2 kategori" di bawah tidak berlaku
  lagi: kartu kembali selalu memuat 3 kategori.

## 4 November 2026 — perbaikan misi (audit)

- Koreksi admin memulihkan data peserta dan menjadi bagian tetap dari seluruh
  grafik, statistik, dan CSV. Tidak ada pilihan mengecualikannya; sumber dan
  alasan koreksi tetap dapat ditelusuri melalui detail dan log admin.
- Dashboard menonjolkan angka ringkasan dan grafik keterlibatan minggu 1–4.
  Grafik wellness dan rokok/vape dipilih per jalur; penjelasan ada di
  "Tentang data", tabel harian di "Detail peserta". Data log melengkapi
  kuesioner, hasil tugas UAT, dan wawancara dalam evaluasi penerimaan.

- Misi Tidur dinilai dari malam yang berakhir pagi itu. Kartu hanya memuatnya
  bila catatan malam memenuhi target, atau targetnya masih bisa dicapai
  berdasarkan batas tidur/bangun level tersebut. Membuka aplikasi pukul 05.00
  tanpa check-in semalam tidak memberi target tidur sebelum 00.30. Draft yang
  lewat batas diganti misi ringan, lalu dikonfirmasi ulang. Di hari seperti itu
  kartu jalur wellness berisi 2 dari 3 kategori level lain ditambah quest
  pendamping, supaya lima kartu tetap berbeda (keputusan tim, menyimpang dari
  "3 kategori per kartu" hanya di hari tanpa catatan tidur).
- "Aku mau tidur" hanya bisa ditekan 18.00–06.00. Satu malam per hari bangun:
  yang lebih panjang dipertahankan, jadi tidur sore tidak menimpa malamnya.
- Progres sebagian Hidrasi sama, entah air dicatat sebelum atau sesudah kartu
  dipilih. Untuk tawaran naik level, misi sebagian dihitung paling banyak
  setengah; untuk turun level tetap dihitung penuh.
- Misi foto makan yang jendelanya habis dalam kurang dari 60 menit memakai
  versi "kapan saja"; "Cari cahaya pagi" diganti quest lain bila kartu dipilih
  setelah 12.00.
- Kolom level di ringkasan riset memakai level terakhir yang diketahui untuk
  minggu tanpa pemakaian; kosong berarti kategori tidak dipakai.
- Kartu yang dibuat admin untuk hari lampau memakai level yang berlaku hari
  itu dan menyimpannya.
- Belum diubah (menunggu tim): target durasi tidur 7–9 jam dan menilai malam
  yang akan datang. Keduanya mengubah isi `tangga_istirahat`.

## 4 November 2026 — dashboard peneliti

- Dashboard peneliti punya tab **Analisis studi**: ringkasan studi, grafik
  minggu 1–4 jalur wellness, grafik harian rokok (batang) dan vape (sesi)
  yang tidak pernah dijumlah, serta detail 28 hari per kode dengan penanda
  hari tanpa data dan isian admin. Batas tafsir tertulis di layar.
- Rata-rata konsumsi = total yang dikonfirmasi ÷ hari yang dicatat. Minggu
  dibandingkan dengan minggu 1 hanya bila keduanya punya minimal 4 hari
  tercatat; bila rata-rata minggu 1 nol, hanya selisih yang ditampilkan.
- CSV "data grafik" memakai angka yang sama dengan grafik, termasuk data
  peserta yang dipulihkan admin.
- Jalur studi, tanggal mulai, dan versi aturan ukur dikunci saat kode P
  pertama kali diberikan (tahap 11, disimpan terpisah sejak tahap 12), jadi
  pindah jalur atau menghapus lalu memberi ulang kode tidak memindahkan
  peserta ke kelompok lain.
- Rata-rata kelompok hanya memakai minggu yang sudah selesai dan menampilkan
  jumlah peserta penyusunnya.
- Belum dikerjakan: peran peneliti terpisah yang hanya baca dan impor hasil
  instrumen penelitian. Kuesioner penerimaan awal dan pasca-pemakaian berasal
  dari kelompok berbeda; bukan pasangan skor sebelum–sesudah per peserta.

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
