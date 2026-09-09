# YouWell — cakupan preview lokal

Implementasi mengacu pada konsep YouWell.MD yang diberikan 5 September 2026.
Login, Supabase, dan layanan AI ditunda sesuai permintaan. Seluruh data aplikasi
versi ini disimpan melalui SharedPreferences di browser, dengan namespace baru
`youwell.local.v2`; tidak membaca atau mengubah backend lama.

| Fitur konsep | Implementasi yang dapat dicoba |
| --- | --- |
| Landing + onboarding | Tiga slide, profiling dua jalur, baseline kebugaran, kondisi cedera, alias persisten, tiga companion |
| Gacha | Sekali per tanggal lokal, deck 5 kartu terfilter jalur/kondisi/tingkat, tersimpan saat reload |
| Adaptive difficulty | Sesudah tiga hari data: >80% naik satu tingkat, <40% turun; low-impact tingkat 1 |
| Checklist + XP | Satu completion per misi, 20 XP; tanpa duplikasi reward |
| Companion | Mori/Milo/Awan, level, pesan kontekstual, status istirahat saat freeze |
| Streak / freeze | Streak harian setelah semua misi tuntas; token memperbaiki tepat satu hari kemarin terlewat |
| Nutrition | Foto privat dikompresi lokal, katalog/manual, konfirmasi porsi, kkal/protein/karbo; hapus catatan |
| Intake | Air +250 ml, target energi/protein/air bisa disunting |
| Aktivitas | Input jenis/jarak/durasi dengan validasi; riwayat dan penghapusan |
| Statistik | Compliance 1/7/30 hari, grafik, aktivitas, riwayat companion, mood, craving khusus jalur reduksi |
| Recap | Kartu 7/30 hari, unduh PNG untuk dibagikan manual, tanpa catatan privat |
| Wall / rooms | Empat feed, alias konsisten, reaksi preset, kiriman pending/approved/rejected |
| Moderasi | Filter aturan lokal untuk kontak/kata kasar/promosi/sinyal krisis; dashboard route /moderator; tidak menerima foto publik |
| Pelaporan | Alasan preset, sembunyikan konten, review/pulihkan di dashboard lokal |
| Vibe map | Peta ilustratif interaktif dengan label data contoh; mood pribadi tidak diterbitkan |
| Squad | Gabung/keluar grup 5 anggota; empat contoh, kontribusi sendiri dari log jalan/lari minggu kalender |
| Buddy | Pasangan contoh acak jalur sama, alias/streak/reaksi; direset saat path berubah |
| FAB | Di semua tab: craving (jalur reduksi), vent, soundscape, bantuan |
| Delay | 5/10 menit berbasis deadline, pemicu, sukses/batal, konfirmasi tidak merokok untuk estimasi hemat |
| Micro-Vent | Teks sementara di memori, efek penghancuran skala/fade, suara, dihapus setelah dilepas |
| Soundscape | Sintesis hujan/ambient serta panduan napas visual, timer 1–3 menit; stop saat ditutup |
| Krisis | Pesan suportif pada kata kunci berisiko di mood, vent, forum; bantuan selalu tersedia |
| Profil | Ubah alias/companion/baseline/biaya/jalur, lencana, ekspor JSON, hapus lokal dengan konfirmasi |

## Batas integrasi yang sengaja belum aktif

- Tidak ada identitas Google, akun admin produksi, sinkronisasi, atau komunikasi antarperangkat.
- Anggota/feed/map contoh diberi label simulasi. Tidak ada operator yang menerima laporan.
- Nutrisi menggunakan estimasi katalog/manual, bukan pengenalan foto AI. Nilai katalog contoh
  bukan basis data nutrisi terverifikasi; cocok untuk mencoba alur input.
- Moderasi serta deteksi krisis memakai kata kunci, bukan AI atau deteksi risiko yang andal.
  UI hanya memberi arahan umum untuk mencari bantuan langsung dari orang tepercaya
  atau tenaga profesional.
- Audio adalah sintesis Web Audio, bukan rekaman hujan, lagu lo-fi, atau narasi manusia.
- Upload foto, audio, unduh JSON/PNG, dan link bantuan saat ini ditargetkan ke **web**.
  Adapter platform mobile masih perlu dibuat sebelum menjanjikan paritas Android/iOS.
- Data browser bukan terenkripsi end-to-end. Micro-Vent tidak masuk penyimpanan maupun log.
- Streak misi berbeda dari keberhasilan delay: menyelesaikan delay tidak membuktikan hari bebas rokok.
- Target kesehatan adalah input pengguna; bukan rekomendasi personal atau pengukuran organ.

## Langkah integrasi selanjutnya

Sesudah feedback UI: tambahkan repository Supabase, login Google, moderator auth,
aturan privasi per tabel, layanan moderasi/pengenalan foto, matching dan agregasi
pengguna nyata, lalu uji Android/iOS. Backend lama telah dikeluarkan agar integrasi
berikutnya dibuat dari model fitur terbaru.
