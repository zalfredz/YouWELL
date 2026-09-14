# YouWell Mobile Development

Project native tersedia di `ios/` dan `android/`. UI dan business logic tetap
ditulis dengan Flutter di `lib/`; Xcode dipakai untuk simulator, signing,
capability iOS, archive, dan distribusi.

## Status fondasi

- Bundle/Application ID awal: `com.youwell.app`.
- Minimum iOS deployment target: iOS 15.
- iPhone menggunakan orientasi portrait.
- Penyimpanan masih local-first melalui `SharedPreferences`.
- Pilih foto, share file/recap, dan buka tautan sudah memakai API native.
- Supabase, Google Sign-In, push notification, dan production signing belum
  diaktifkan. Tambahkan setelah alur mobile stabil.
- App icon dan launch screen masih placeholder Flutter dan harus diganti
  sebelum TestFlight.

## Setup Mac satu kali

Pastikan Xcode berada di `/Applications/Xcode.app`, lalu jalankan:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS
flutter doctor -v
```

Jika perintah pertama mengatakan path tidak ditemukan, pindahkan instalasi
Xcode ke folder `/Applications` dan pastikan nama aplikasinya `Xcode.app`.
Perintah `sudo xcode-select` meminta password akun Mac dan harus dijalankan
langsung oleh pemilik perangkat.

## Setup setelah clone

Bagian ini hanya untuk perangkat yang **belum memiliki project YouWELL**.
Jika folder project sudah terbuka di VS Code, jangan jalankan `git clone` lagi
di dalamnya; langsung mulai dari `flutter pub get` pada root project.

```bash
git clone https://github.com/zalfredz/YouWELL.git
cd YouWELL
cp config/env/development.example.json config/env/development.json
flutter pub get
open ios/Runner.xcworkspace
```

Jangan membuka `Runner.xcodeproj`; gunakan `Runner.xcworkspace` agar integrasi
plugin Flutter ikut dimuat.

## Menjalankan di iPhone Simulator

1. Buka Simulator dari Xcode: **Xcode > Open Developer Tool > Simulator**.
2. Di terminal, jalankan `flutter devices` dan salin ID simulator.
3. Jalankan:

```bash
bash scripts/run-mobile.sh -d "ID-ATAU-NAMA-SIMULATOR"
```

Contoh jika Flutter menampilkan perangkat bernama `iPhone 17 Pro`:

```bash
bash scripts/run-mobile.sh -d "iPhone 17 Pro"
```

Saat proses aktif, tekan `r` untuk hot reload, `R` untuk hot restart, dan `q`
untuk berhenti.

## Menjalankan lewat VS Code

1. Buka root folder `YouWELL`, bukan folder `ios`.
2. Nyalakan iPhone Simulator.
3. Pilih simulator pada device selector VS Code.
4. Tekan `F5`.

Jika perlu build-time environment, gunakan script terminal di atas supaya
`config/env/development.json` otomatis ikut dipakai.

## Signing di Xcode

Di `Runner.xcworkspace`, pilih **Runner > TARGETS Runner > Signing &
Capabilities**:

1. Aktifkan **Automatically manage signing**.
2. Pilih Apple Developer Team.
3. Pastikan Bundle Identifier unik. Ganti `com.youwell.app` jika identifier
   tersebut bukan milik akunmu.

Simulator tidak memerlukan paid developer account. Perangkat fisik memerlukan
Apple ID/signing, sedangkan TestFlight dan App Store memerlukan Apple Developer
Program.

## File mobile yang biasa diubah

| Kebutuhan | File/folder |
| --- | --- |
| UI dan logic bersama | `lib/` |
| Implementasi API perangkat | `lib/core/platform/platform_native.dart` |
| Nama dan permission iOS | `ios/Runner/Info.plist` |
| Bundle ID/signing iOS | `ios/Runner.xcodeproj/project.pbxproj` / Xcode |
| App icon iOS | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` |
| Konfigurasi Android | `android/app/build.gradle.kts` |
| Permission Android | `android/app/src/main/AndroidManifest.xml` |
| Environment lokal | `config/env/development.json` |

Jangan commit `config/env/development.json`, signing key, provisioning profile,
`local.properties`, atau credential layanan.
