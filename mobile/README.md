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

The API base URL is selected centrally through `API_BASE_URL`. Set it to the API origin, with or without a trailing `/api`; the app adds exactly one `/api` prefix. With no define, the Android emulator uses `http://10.0.2.2:3000/api`, while web and other platforms use `http://localhost:3000/api`.

After a successful sign-in, the app remembers the session on the device and restores it at startup. Sign out from the profile screen to clear the saved session. A session may require signing in again if its server-issued token expires or is revoked.

For local testing on a physical Android device, connect the phone and development computer to a network where the phone can reach the computer, then pass the computer's LAN origin:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.25:3000
```

Replace the example IP with the computer's address. Confirm that `http://<computer-LAN-IP>:3000/api/health` is reachable from the phone. Plain HTTP is supported only in Android debug builds; release builds should use HTTPS.

### Outdoor testing with automatic Cloudflare Quick Tunnel discovery

Configure and deploy the stable `workers.dev` discovery Worker once by following [the tunnel discovery setup](../backend/tunnel-discovery/README.md). Set the Worker endpoint and its publish secret in `backend/.env`. Install `cloudflared` on Windows if needed:

```powershell
winget install --id Cloudflare.cloudflared --exact
```

From `backend/`, start both the API and tunnel together:

```powershell
npm run dev
```

The terminal prints the generated public URL and tunnel status. The backend also saves the current origin to the ignored `backend/.tunnel-url` file and publishes it to the Worker. The computer, backend, and tunnel must remain running during testing. The tunnel exposes the Express API only; do not expose PostgreSQL or Valhalla.

Build an APK once with the stable discovery endpoint:

```powershell
Set-Location C:\PathCraft\mobile
flutter build apk --release --dart-define=API_DISCOVERY_URL=https://<worker-name>.<workers-subdomain>.workers.dev/api/tunnel
```

Install it on the phone:

```powershell
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

The app caches the current tunnel URL and asks the stable Worker for an update if that URL stops working. Restarting `npm run dev` generates a new Quick Tunnel hostname and publishes it; the same installed APK can discover it without rebuilding. The Worker requires a Cloudflare account but no purchased domain. For production, configure `API_BASE_URL` with the deployed HTTPS API; that explicit setting disables Quick Tunnel discovery.

## Validate changes

From `mobile/`:

```powershell
flutter analyze
flutter test
```

For frontend development conventions and UI validation guidance, see [docs/frontend-development.md](../docs/frontend-development.md). The `ai/` Python service is a legacy scorer and is not required to run the app.
