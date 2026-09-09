# Struktur project YouWell

Kode disusun berdasarkan tanggung jawab agar perubahan satu fitur tidak perlu
membuka file besar yang mencampur seluruh aplikasi.

```text
lib/
├── main.dart                         # entry point yang sangat tipis
├── app/                              # bootstrap, theme root, navigation shell
├── application/                      # state dan command lintas fitur
├── core/                             # config, theme, platform, tipe, utility
├── data/                             # persistence dan bentuk snapshot lokal
├── features/
│   ├── activity/                     # input aktivitas
│   ├── community/                    # feed, rooms, squad, buddy, vibe map
│   ├── home/                         # quest, progress, halaman Home
│   ├── moderation/                   # filter dan moderator preview
│   ├── mood/                         # check-in mood
│   ├── nutrition/                    # makanan, porsi, dan target
│   ├── onboarding/                   # landing dan profiling
│   ├── profile/                      # profil dan kontrol data
│   ├── recap/                        # kartu progress PNG
│   ├── relief/                       # craving, vent, soundscape
│   ├── statistics/                   # dashboard statistik
│   ├── support/                      # crisis signal dan bantuan
│   └── web/                          # landing, workspace, recap publik
└── shared/widgets/                   # komponen UI lintas fitur
```

## Aliran data

```text
Widget fitur
   ↓ membaca state / memanggil command bernama
WellnessController
   ↓ serialisasi state secara berurutan
WellnessRepository
   ↓
SharedPreferences (preview lokal)
```

Widget tidak mengubah map penyimpanan secara langsung. Command seperti
`addMeal`, `logActivity`, `switchPath`, dan `advancePreviewDays` menjadi satu
pintu perubahan data. Saat Supabase dihubungkan, implementasi repository dapat
diganti tanpa memindahkan UI ke file baru.

## Konvensi folder fitur

- `presentation/`: halaman, sheet, dan widget yang dilihat pengguna.
- `domain/`: aturan produk yang tidak bergantung pada UI.
- `data/`: katalog atau sumber data khusus fitur.
- File bersama hanya masuk `core/` atau `shared/` jika dipakai beberapa fitur.

## Entry point dan environment

`main.dart` hanya memanggil `app/bootstrap.dart`. Bootstrap memilih repository,
membaca data lama, membuat controller, lalu menjalankan aplikasi.

`app/web_experience_gate.dart` memberi workspace dan dashboard moderasi frame
desktop edge-to-edge. Landing serta recap publik tidak melewati gate agar tetap nyaman
di HP. Browser sempit yang membuka workspace menerima prompt aplikasi mobile;
build Android/iOS tetap memakai layout native layar penuh.

Halaman web publik dan workspace tinggal di `features/web/presentation/`.
Keputusan cakupan dan rute tercatat dalam `docs/WEB_PRODUCT.md`.

Nilai environment dibaca di `core/config/app_environment.dart` melalui
`--dart-define-from-file`. File `*.example.json` masuk Git; file environment
lokal tanpa suffix `.example` diabaikan Git.

## Integrasi backend nanti

Tambahkan implementasi repository Supabase di `data/repositories/`, lalu pilih
repository tersebut di `app/bootstrap.dart`. Authentication dapat menjadi gate
di `app/youwell_app.dart`. Aturan moderasi dan agregasi sosial tetap harus
ditegakkan server-side ketika data nyata mulai digunakan.
