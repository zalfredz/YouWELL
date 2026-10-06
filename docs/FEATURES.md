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
| Delay Craving & Habit Swap | Timer tunda sesuai anak tangga + catatan Habit Swap, khusus jalur rokok/vape. Dibuka dari Home. Reset dihapus dari mobile (keputusan tim 6 Okt 2026) |
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
- Reset dihapus dari mobile; Delay Craving & Habit Swap dipindah ke halaman sendiri.
  Napas sebagai opsi Habit Swap tetap tersedia khusus jalur reduction.

## Aturan data dan penelitian

- Reward mobile aktif saat AppShell mobile dipakai; layout/widget web tidak diubah.
- Koreksi/hapus jurnal tidak mencabut XP dan tidak mencetak reward baru.
- Durasi/jarak sesi gerak tidak bisa diedit, baik di UI maupun API controller;
  hanya catatan pribadi yang dapat diubah. Hapus sesi jika keliru.
- Menghapus sesi menghitung ulang bukti quest dan progress parsial. Quest yang
  kehilangan bukti dikeluarkan dari evaluasi tangga dan `quests_done`/`quest_days`
  penelitian, tanpa mencabut status reward, XP, atau level yang sudah diterima.
  Bukti lain yang masih memenuhi target tetap sah. Tawaran naik yang belum
  diterima dicek ulang, termasuk saat snapshot lama dibuka.
- Angka durasi/jarak yang pernah dikoreksi manual oleh versi lama tidak menjadi
  bukti quest. Mengedit catatan saja pada versi baru tidak membatalkan bukti.
- `opened_days`, `activity_days`, dan `quest_days` di ringkasan UAT dibedakan.
  `active_days` berarti hari unik membuka aplikasi, sama dengan `opened_days`.
  Tidak harus selesai quest untuk dihitung aktif. Ritme gamifikasi 4/7 tetap
  menggunakan hari quest selesai, bukan ukuran keterlibatan penelitian.
- Ekspor ringkasan sekarang memakai `schema_version: 2`. Ringkasan yang sudah
  diekspor sebelumnya harus diekspor ulang untuk memakai definisi yang benar.
- Persetujuan UAT bisa ditarik lokal tanpa menghalangi penggunaan aplikasi.
  Penarikan ini tidak menghapus salinan yang sudah dibagikan secara manual.
- Tes otomatis tidak menggantikan tujuh skenario UAT native iOS/Android atau
  evaluasi calon pengguna. Community multi-user menunggu backend.
