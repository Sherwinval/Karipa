# Karipa

Karipa is an Android app for planning and recording outdoor activities. It supports walking, jogging, running, and cycling, with route planning powered by Valhalla and OpenStreetMap.

## Features

- Plan routes from an activity type, target distance, and route preferences
- Register, sign in, verify email, and manage a profile
- Record activities with or without a planned route
- Review saved activities and view activity history
- Compare distance on the weekly leaderboard
- Choose metric or imperial units and light or dark appearance

Routes are verified against Valhalla before they are returned. Groq is optional and is used only for preference interpretation and route-ranking assistance; routing geometry and distance always come from Valhalla.

## Project structure

| Directory | Purpose |
| --- | --- |
| `mobile/` | Flutter Android application |
| `backend/` | Express and TypeScript API |
| `backend/prisma/` | PostgreSQL/PostGIS schema and migrations |
| `docs/` | Database and frontend setup guides |

The Python project in `ai/` is a legacy route scorer and is not required to run Karipa.

## Requirements

- Git
- Node.js 20 or later
- Flutter SDK with Dart 3.3 or later
- PostgreSQL 16 with PostGIS
- Android Studio or a connected Android device
- A reachable Valhalla server

## Quick start

### 1. Set up PostgreSQL

Create a PostgreSQL database with PostGIS enabled. Follow [the database setup guide](docs/database-setup.md). Do not use `docker-compose.yml` for local PostGIS setup; it defines a plain PostgreSQL container.

### 2. Configure and start the API

```powershell
Copy-Item backend\.env.example backend\.env
```

Edit `backend/.env` with at least:

- `DATABASE_URL` and `DIRECT_URL`
- `JWT_SECRET`
- `LOCATION_DATA_ENCRYPTION_KEY`
- `VALHALLA_BASE_URL`

Then run:

```powershell
Set-Location backend
npm install
npx prisma generate
npx prisma migrate dev
npm run dev
```

Then check:

- `http://localhost:3000/api/health`
- `http://localhost:3000/api/health/database`

Groq is optional. Set `GROQ_API_KEY` to enable it. Leave it unset to use deterministic routing and ranking. SMTP settings are required for registration and password recovery email delivery. Configure `PASSWORD_RECOVERY_SECRET` for recovery; see [password recovery setup and verification](docs/password-recovery.md).

For Cloudflare Quick Tunnel and automatic mobile discovery, see [the tunnel setup guide](backend/tunnel-discovery/README.md).

### 3. Run the mobile app

```powershell
Set-Location ..\mobile
flutter pub get
flutter devices
flutter run
```

The Android emulator uses `http://10.0.2.2:3000/api` by default. For a physical device, use the computer's reachable LAN address:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.25:3000
```

See [the mobile setup guide](mobile/README.md) for tunnel discovery, release builds, and additional testing instructions.

## Validation

Run backend checks:

```powershell
Set-Location backend
npm test
npm run build
```

Run mobile checks:

```powershell
Set-Location mobile
flutter analyze
flutter test
```
