# Struktur project YouWell

```text
lib/
├── app/                 # bootstrap, root app, mobile shell, web gate
├── application/         # WellnessController sebagai use-case boundary
├── core/                # config, theme, platform adapter, utility
├── data/                # snapshot dan repository lokal
├── features/
│   ├── activity/        # gerak, Meal Snap, hidrasi, riwayat
│   ├── companion/       # evolusi, aksesori, animasi reward mobile
│   ├── community/       # Wall, Squad, Buddy, Vibe Map, Admin
│   ├── home/            # companion, quest, Daily Card
│   ├── onboarding/      # personalisasi awal
│   ├── profile/         # preferences dan kontrol data
│   ├── progress/        # insight progress mobile
│   ├── reset/           # jeda mobile, stretch, Delay Craving, Habit Swap
│   └── web/             # landing, workspace, focus, recap publik
└── shared/widgets/      # komponen visual lintas fitur
```

## Aliran data

```text
UI → WellnessController → WellnessRepository → SharedPreferences
```

Widget tidak menulis storage secara langsung. State versi 3 hanya menyimpan
profil, rencana harian, reward/aksesori, aktivitas, sesi fokus web, habit delay,
dan state prototype komunitas. Check-in energi tidak lagi tersedia; snapshot
lama tetap mempertahankan catatannya untuk ekspor. Struktur
ini sengaja kecil agar UX dapat diubah cepat sebelum kontrak backend dibekukan.

## Integrasi backend nanti

Setelah UX stabil, tambahkan Auth gate di `app/youwell_app.dart`, role Admin,
RLS, dan repository Supabase di `data/repositories/`. Web dan mobile tetap
memakai controller/model yang sama sehingga data bisa sinkron tanpa menyamakan
seluruh tampilan.
