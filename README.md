# YouWell

YouWell adalah **better-life companion** untuk membangun ritme harian lewat
langkah kecil, companion, dan progress yang tidak menghukum. Produk saat ini
local-first: belum ada Google Auth, Supabase, pengguna komunitas nyata, atau
data cloud.

## Produk saat ini

- Mobile: Home, Reset, Progress, Community, dan Profile dari avatar.
- Web: landing, Home, Focus Station, Progress, Community, Admin, dan recap.
- Core loop: pilih 1 dari 5 Daily Card berisi 3–5 quest adaptif, selesaikan,
  dapatkan XP, dan tumbuhkan companion.
- Path reduction opsional untuk habit swap rokok/vape; bukan identitas utama.

## Menjalankan

```bash
# Web preview
bash scripts/preview.sh

# iOS/Android simulator atau device
bash scripts/run-mobile.sh -d "NAMA-ATAU-ID-DEVICE"
```

Untuk hot reload, jalankan dari VS Code/terminal lalu tekan `r`, atau simpan
file saat sesi debug VS Code aktif. Push GitHub tidak diperlukan untuk melihat
perubahan lokal.

Konfigurasi lokal ada di `config/env/development.json` dan diabaikan Git.
Salin dari `config/env/development.example.json` setelah clone.

## File utama

| Kebutuhan | File |
| --- | --- |
| Navigasi mobile | `lib/app/app_shell.dart` |
| Aktivitas, Meal Snap, dan jalan/lari mobile | `lib/features/activity/` |
| Home + companion | `lib/features/home/presentation/home_page.dart` |
| Daily Card popup | `lib/features/home/presentation/daily_card_draw_dialog.dart` |
| Aturan quest adaptif | `lib/features/home/domain/daily_card_generator.dart` |
| Reset / quick focus | `lib/features/reset/presentation/reset_page.dart` |
| Progress | `lib/features/progress/presentation/progress_page.dart` |
| Community, Squad, Buddy, Vibe Map | `lib/features/community/presentation/community_page.dart` |
| Antrean Admin | `lib/features/community/presentation/admin_moderation_page.dart` |
| Onboarding | `lib/features/onboarding/presentation/onboarding_page.dart` |
| Profile & settings | `lib/features/profile/presentation/profile_page.dart` |
| Workspace web | `lib/features/web/presentation/web_workspace_page.dart` |
| Focus Station web | `lib/features/web/presentation/pomodoro_page.dart` |
| Semua perubahan data | `lib/application/wellness_controller.dart` |
| Skema data lokal | `lib/data/models/wellness_snapshot.dart` |

## Verifikasi

```bash
flutter analyze
flutter build web --release --no-web-resources-cdn \
  --dart-define-from-file=config/env/development.example.json
flutter build ios --simulator --no-codesign \
  --dart-define-from-file=config/env/development.example.json
```

Detail arsitektur ada di [docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md)
dan panduan mobile di [docs/MOBILE_DEVELOPMENT.md](docs/MOBILE_DEVELOPMENT.md).
