# Struktur project YouWell

```text
lib/
├── app/                 # bootstrap, root app, mobile shell, web gate
├── application/         # WellnessController sebagai use-case boundary
├── core/                # config, theme, platform adapter, utility
├── data/                # snapshot dan repository lokal
├── features/
│   ├── checkin/         # energy check-in ringan
│   ├── home/            # companion, quest, Daily Card
│   ├── onboarding/      # personalisasi awal
│   ├── profile/         # preferences dan kontrol data
│   ├── progress/        # insight progress mobile
│   ├── reset/           # quick focus dan micro-actions
│   └── web/             # landing, workspace, focus, recap publik
└── shared/widgets/      # komponen visual lintas fitur
```

## Aliran data

```text
UI → WellnessController → WellnessRepository → SharedPreferences
```

Widget tidak menulis storage secara langsung. State versi 3 hanya menyimpan
profil, rencana harian, check-in energi, sesi fokus, dan habit delay. Struktur
ini sengaja kecil agar UX dapat diubah cepat sebelum kontrak backend dibekukan.

## Integrasi backend nanti

Setelah UX stabil, tambahkan Auth gate di `app/youwell_app.dart` dan repository
Supabase di `data/repositories/`. Web dan mobile tetap memakai controller/model
yang sama sehingga data bisa sinkron tanpa menyamakan seluruh tampilan.
