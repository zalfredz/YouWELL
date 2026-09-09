# Daily Card System

Daily Card System adalah loop utama preview YouWell Web.

```text
Daily Card Draw → swipe deck berisi 5 kartu paket → pilih 1 → reveal 3–5 task → Commit (locked) → Complete task → XP + progress → streak
```

## Status kartu

- `available`: kartu paket berada di deck dan belum dipilih.
- `committed`: satu kartu paket dipilih; seluruh task di dalamnya masuk ke
  Today’s Progress dalam status `committed`.
- `completed`: setiap task di dalam paket dapat diselesaikan sendiri dan XP
  task tersebut dihitung pada progress.

Sebelum commit, pengguna boleh **dua kali** kembali ke deck. Kartu yang telah
dibuka akan menjadi `passed`: tetap tertutup, nonaktif, dan tidak dapat dipilih
lagi. Pilihan ketiga harus di-commit. Aturan ini memberi ruang untuk salah pilih
tanpa memungkinkan pengguna membuka seluruh deck untuk mencari paket paling
mudah. Tidak ada uncommit atau reroll setelah kartu di-commit.

## Filter draw

`DailyCardGenerator` memilih tepat 5 kartu paket secara deterministik untuk
satu hari. Masing-masing paket berisi 3–5 task. Pool disaring oleh path
pengguna, low-impact preference, difficulty, compliance 7 hari, dan lama
penggunaan aplikasi. Pengguna baru atau yang ritmenya sedang rendah menerima
paket tiga task difficulty 1 terlebih dahulu. Path reduction selalu mendapat
peluang `Reduction Challenge`.

Setiap kartu mendapat warna collectible yang disimpan pada data deck. Warna itu
dibawa ke animasi reveal dan tombol commit, sehingga pilihan pengguna tetap
konsisten secara visual.

## Progression

- XP berasal dari nilai `xp` pada task yang completed, bukan nilai tetap.
- Daily progress menggunakan completed dibanding seluruh task yang committed;
  kartu paket yang tidak terpilih tidak menurunkan progress pengguna.
- Hari dianggap tuntas ketika semua task dalam paket yang di-commit selesai.
  Nilai ini dipakai oleh streak dan token freeze.

## File utama

- `lib/features/home/domain/daily_card_generator.dart`: pool serta filter.
- `lib/application/wellness_controller.dart`: state transitions dan persistence.
- `lib/features/home/domain/progress_calculator.dart`: XP, compliance, streak.
- `lib/features/web/presentation/web_workspace_page.dart`: Daily Card Draw dan
  Today’s Progress.
