# Cakupan produk lokal

## Sudah tersedia

| Area | Implementasi |
| --- | --- |
| Onboarding | Pilih arah wellness/reduction, pace, low-impact, alias, companion |
| Home mobile | Companion hero animasi/sentuh, feedback XP, 3–5 quest, rating usaha, tawaran tangga |
| Companion mobile | 5 tahap tumbuh, evolusi visual, lemari aksesori/latar, target hadiah berikutnya |
| Reward mobile | Bonus Hari Penuh 20 XP sekali per hari, ID persisten, lencana privat |
| Daily Card | Lima kartu collectible, spin acak, swipe, reveal, satu kali ganti, commit; mobile punya Santai/Normal dan tema |
| Aktivitas mobile | Foto/catatan makan lokal, timer/GPS foreground, hidrasi, riwayat detail, koreksi/hapus |
| Reset mobile | Reset 60 detik dan stretch; habit delay untuk reduction. Dibuka dari Home, tanpa fokus atau hidrasi duplikat |
| Perjalanan mobile | Ritme 4/7, kalender 28 hari, lencana, tangga quest, XP, aktivitas, total menit ditunda |
| Community mobile | Encouragement Wall lokal, post menunggu review, reaksi cepat, laporan; seed post berlabel contoh |
| Admin | Antrean post pending, approve/reject, dan penyelesaian laporan |
| Profile | Tema, path, low-impact, kurangi animasi, getaran, ekspor/hapus lokal, persetujuan dan kode UAT |
| Web | Landing, Home workspace, Focus Station, Progress, public recap |

## Sengaja ditunda

- Google Auth dan Supabase sync.
- Identitas komunitas nyata, matching real-time, dan moderasi server.
- Squad, Buddy, dan Vibe Map nyata: tetap roadmap, demo tidak ditampilkan di mobile.
- Push notification dan reminder terjadwal.
- Machine learning. Personalisasi saat ini rule-based dan transparan.
- Integrasi HealthKit/Google Fit dan tracking otomatis.
- Analytics produksi, crash reporting, dan release signing.

Tidak tersedia: estimasi kalori/AI makanan, upload foto ke cloud, tracking GPS
background, komentar bebas, peringkat kompetitif, dan hukuman karena absen.
Web tidak dirombak dalam revisi mobile ini.

## Penyederhanaan mobile

- Check-in energi dan panel energi dihapus; catatan lama tetap ikut ekspor lokal.
- Fokus/Pomodoro hanya tersedia di web. Koleksi sesi fokus bersama dipertahankan.
- Lima tema mobile: Gerak Ringan, Energi Segar, Istirahat, Hidrasi & Makan,
  Udara Segar. Quest pendamping produktivitas/relasi tidak masuk pool mobile.
- Core Quest, tangga Istirahat/Hidrasi, dan quest reduction tetap ada.
  Pada jalur reduction, Energi Segar menyediakan Habit Swap/pemicu sesuai level.
- Kartu yang sudah dibuka atau di-commit tidak diganti diam-diam.
- Penggantian Reset menjadi jeda fisik masih menunggu keputusan; belum diterapkan.

## Aturan data dan penelitian

- Reward mobile aktif saat AppShell mobile dipakai; layout/widget web tidak diubah.
- Koreksi/hapus jurnal tidak mencabut XP dan tidak mencetak reward baru.
- `opened_days`, `activity_days`, dan `quest_days` di ringkasan UAT dibedakan.
  `active_days` kini berarti hari dengan quest selesai, sama dengan `quest_days`.
- Persetujuan UAT bisa ditarik lokal tanpa menghalangi penggunaan aplikasi.
  Penarikan ini tidak menghapus salinan yang sudah dibagikan secara manual.
- Tes otomatis tidak menggantikan tujuh skenario UAT native iOS/Android atau
  evaluasi calon pengguna. Community multi-user menunggu backend.
