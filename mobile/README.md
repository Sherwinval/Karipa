# Karipa mobile app

The Flutter app supports route planning, GPS activity recording, activity history, profile settings, and the weekly leaderboard. Planned routes use Valhalla; the app displays maps with OpenStreetMap tiles.

## Requirements

- Flutter SDK with Dart 3.3 or later
- Android Studio with an emulator, or a connected Android device
- A running Karipa API and configured database; see the [project setup](../README.md#setup)

## Run on Android

From the repository root:

```powershell
Set-Location mobile
flutter pub get
flutter devices
flutter run
```

The Android emulator connects to the API at `http://10.0.2.2:3000/api` by default. For a physical Android device, connect the phone and development computer to a network where the phone can reach the computer, then pass the computer's LAN address:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.25:3000/api
```

Replace the example IP with the computer's address. Confirm that `http://<computer-LAN-IP>:3000/api/health` is reachable from the phone. Plain HTTP is supported only in Android debug builds; use HTTPS for release builds.

## Validate changes

From `mobile/`:

```powershell
flutter analyze
flutter test
```

For frontend development conventions and UI validation guidance, see [docs/frontend-development.md](../docs/frontend-development.md). The `ai/` Python service is a legacy scorer and is not required to run the app.
