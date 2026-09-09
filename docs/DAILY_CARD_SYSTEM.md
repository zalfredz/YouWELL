# Daily Card System

Daily Card System adalah loop utama preview YouWell Web.

```text
Daily Card Draw → Available → Commit (locked) → Complete → XP + progress → streak
```

## Status kartu

- `available`: muncul pada draw dan belum dipilih.
- `committed`: pengguna memilih kartu; pilihan terkunci untuk hari ini.
- `completed`: challenge selesai dan XP kartu dihitung pada progress.

Tidak ada uncommit atau reroll setelah kartu di-commit.

## Filter draw

`DailyCardGenerator` memilih 3–5 kartu secara deterministik untuk satu hari.
Pool disaring oleh path pengguna, low-impact preference, difficulty, compliance
7 hari, dan lama penggunaan aplikasi. Path reduction selalu mendapat peluang
`Reduction Challenge`.

## Progression

- XP berasal dari nilai `xp` pada kartu yang completed, bukan nilai tetap.
- Daily progress menggunakan completed dibanding committed; kartu available
  tidak menurunkan progress pengguna.
- Hari dianggap tuntas ketika semua kartu yang di-commit hari itu completed.
  Nilai ini dipakai oleh streak dan token freeze.

## File utama

- `lib/features/home/domain/daily_card_generator.dart`: pool serta filter.
- `lib/application/wellness_controller.dart`: state transitions dan persistence.
- `lib/features/home/domain/progress_calculator.dart`: XP, compliance, streak.
- `lib/features/web/presentation/web_workspace_page.dart`: Daily Card Draw dan
  Today’s Progress.
