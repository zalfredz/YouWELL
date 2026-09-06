# YouWell

Preview Flutter web untuk mengeksplorasi seluruh alur produk sebelum login dan
backend Supabase dihubungkan. Data tersimpan secara lokal di browser.

## Menjalankan aplikasi

```bash
bash scripts/preview.sh
```

Buka [http://localhost:8080](http://localhost:8080). Hentikan server dengan
`Ctrl+C`. Untuk hot reload selama mengubah tampilan:

```bash
.tools/flutter/bin/flutter run -d chrome --web-port 8080 \
  --dart-define-from-file=config/env/development.json
```

Flutter SDK lokal berada di `.tools/flutter` dan tidak masuk Git. Jika Flutter
sudah terpasang secara global, script otomatis memakai instalasi global.

## Konfigurasi environment

File lokal yang dipakai saat development:

```text
config/env/development.json
```

File tersebut diabaikan Git. Template yang aman untuk Git tersedia di
`config/env/development.example.json` dan `production.example.json`.

Salin template ketika membuat environment baru. `SUPABASE_URL` dan
`SUPABASE_PUBLISHABLE_KEY` sudah disediakan sebagai placeholder untuk integrasi
berikutnya, tetapi belum dipakai aplikasi. Jangan menaruh service-role key atau
client secret di file Flutter karena nilai build web dapat dilihat pengguna.
Isi `PLAY_STORE_URL` dan `APP_STORE_URL` setelah aplikasi mobile diterbitkan.
Pengunjung website dari layar di bawah 1080 px akan melihat halaman download;
tombolnya otomatis memilih store sesuai perangkat.

## File yang biasa diubah

| Yang ingin diubah | File |
| --- | --- |
| Warna aplikasi | `lib/core/theme/app_colors.dart` |
| Theme, tombol, dan input | `lib/core/theme/app_theme.dart` |
| Menu/sidebar/bottom navigation | `lib/app/app_shell.dart` |
| Frame web 16:9 dan halaman download mobile | `lib/app/web_experience_gate.dart` |
| Landing dan onboarding | `lib/features/onboarding/presentation/onboarding_page.dart` |
| Tampilan Home | `lib/features/home/presentation/home_page.dart` |
| Daftar dan aturan misi | `lib/features/home/domain/quest_generator.dart` |
| XP, streak, freeze, difficulty | `lib/features/home/domain/progress_calculator.dart` |
| Statistik | `lib/features/statistics/presentation/statistics_page.dart` |
| Daftar makanan | `lib/features/nutrition/data/food_catalog.dart` |
| Form makanan/target nutrisi | `lib/features/nutrition/presentation/` |
| Komunitas, squad, buddy, vibe map | `lib/features/community/` |
| Moderasi lokal | `lib/features/moderation/` |
| Craving timer, Micro-Vent, audio | `lib/features/relief/` |
| Profil dan kontrol data | `lib/features/profile/` |
| Semua perubahan data aplikasi | `lib/application/wellness_controller.dart` |
| Struktur data lokal awal | `lib/data/models/wellness_snapshot.dart` |
| JavaScript foto/audio/download web | `web/scripts/platform.js` |

Penjelasan lengkap ada di [struktur project](docs/PROJECT_STRUCTURE.md). Cakupan
fitur dan batas preview ada di [daftar fitur](docs/FEATURES.md).

## Build untuk hosting

```bash
.tools/flutter/bin/flutter build web --release \
  --no-web-resources-cdn \
  --pwa-strategy=none \
  --dart-define-from-file=config/env/production.example.json
```

Upload isi folder `build/web` ke static hosting seperti Netlify atau Vercel.
GitHub Actions memeriksa kode, membangun web, dan menyediakan artifact
`youwell-web-preview` pada setiap push ke `main`.

## Pemeriksaan kode

```bash
.tools/flutter/bin/flutter analyze
.tools/flutter/bin/flutter build web --release \
  --no-web-resources-cdn \
  --pwa-strategy=none \
  --dart-define-from-file=config/env/development.example.json
```

File pemeriksaan sementara harus dihapus setelah digunakan. Repository tidak
menyimpan folder `test/`, hasil build, cache Flutter, atau SDK lokal.
