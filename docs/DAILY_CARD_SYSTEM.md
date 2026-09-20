# Daily Card System

Daily Card sekarang adalah bonus ritual, bukan sumber seluruh rencana harian.

```text
3 core quests dibuat otomatis
        +
swipe 5 bonus cards → reveal 1 → maksimal 2 kali ganti → commit
        ↓
4 langkah hari ini → complete → XP → companion tumbuh
```

Core quest selalu mencakup Body, Energy, dan Lifestyle. Untuk path reduction,
Lifestyle diganti Reduction/Habit Swap. Generator menyaring difficulty,
low-impact, penggunaan awal, dan completion rate tujuh hari dengan aturan yang
dapat dijelaskan; belum ada machine learning.

Satu bonus card berisi tepat satu task. Kartu yang dilewati menjadi nonaktif,
dan card yang telah di-commit tidak dapat diganti. Progress menghitung semua
quest hari itu tanpa streak reset atau freeze token.

File utama:

- `features/home/domain/daily_card_generator.dart`: pool dan filter.
- `features/home/presentation/daily_card_draw_dialog.dart`: ritual swipe/reveal.
- `application/wellness_controller.dart`: state transition dan persistence.
- `features/home/domain/progress_calculator.dart`: XP dan completion rate.
