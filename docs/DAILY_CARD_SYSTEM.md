# Daily Card System

Daily Card adalah pintu masuk rencana harian. Satu kartu berisi satu paket quest.

```text
5 paket kartu tersaring sesuai path, pace, dan progres
        ↓
spin acak → swipe/reveal 1 kartu → maksimal 1 kali ganti → commit
        ↓
3–5 quest hari ini → complete → XP → companion tumbuh
```

Setiap paket mencakup setidaknya satu quest Body, Energy, dan Lifestyle. Untuk
path reduction, Lifestyle diganti Reduction/Habit Swap. Level ringan berisi 3
quest, seimbang 4, dan lebih aktif 5. Pengguna baru atau dengan compliance rendah
dimulai dari level ringan. Low-impact dan path menyaring pool sebelum lima paket
dibentuk. Personalisasi masih rule-based dan dapat dijelaskan; belum ada machine
learning.

Kartu yang dilewati menjadi abu-abu dan nonaktif. Paket yang telah di-commit
tidak dapat diganti. Progress menghitung quest dalam paket terpilih tanpa streak
reset atau freeze token. Draft lama tanpa quest selesai dimigrasikan tanpa
menghapus air atau pilihan yang sudah dilewati; hari lama yang sudah dimainkan
tetap dipertahankan.

File utama:

- `features/home/domain/daily_card_generator.dart`: pool dan filter.
- `features/home/presentation/daily_card_draw_dialog.dart`: ritual swipe/reveal.
- `application/wellness_controller.dart`: state transition dan persistence.
- `features/home/domain/progress_calculator.dart`: XP dan completion rate.
