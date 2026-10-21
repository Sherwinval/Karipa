# Karipa

Karipa is a mobile route-planning and activity-tracking app for walking, jogging, running, and cycling. It pairs a Flutter app with a TypeScript API and PostgreSQL/PostGIS database.

## Current features

- Plan routes using Valhalla routing and OpenStreetMap maps.
- Register, sign in, verify email, and manage a profile.
- Track planned routes or record an activity without a route; review and save recordings to activity history.
- View a weekly distance leaderboard.
- Use metric or imperial units and light or dark appearance.

Route ranking can use Gemini for eligible ties when configured; deterministic ranking is used otherwise. Calorie values are estimates. Activity recording currently requires the app to remain in the foreground; background tracking and offline synchronization are not supported.

## Repository layout

- `mobile/` — Flutter application. See [mobile/README.md](mobile/README.md).
- `backend/` — Express, TypeScript, and Prisma API.
- `backend/prisma/` — PostgreSQL schema and migrations.
- `ai/` — legacy Python route scorer; it is not used by the current route-generation flow.
- `docs/` — database and frontend development guides.

## Prerequisites

- Git
- Node.js 20 or later and npm
- Flutter SDK with Dart 3.3 or later
- PostgreSQL 16 with PostGIS, or a compatible managed PostgreSQL/PostGIS database
- Android Studio and an Android emulator or device to run the Android app

## Setup

### 1. Configure PostgreSQL

Create a database with PostGIS enabled. For local setup instructions, see [docs/database-setup.md](docs/database-setup.md). Do not use `docker-compose.yml` as a PostGIS-ready database; it starts a plain PostgreSQL container.

### 2. Configure and start the API

Copy `backend/.env.example` to `backend/.env`, then set the database URLs and a secure `JWT_SECRET`. Configure a reachable Valhalla server using `VALHALLA_BASE_URL`. Gemini ranking is optional; set `GEMINI_API_KEY` to enable it. SMTP settings are optional for email delivery.

From the repository root, run:

```powershell
Set-Location backend
npm install
npx prisma generate
npx prisma migrate dev
npm run dev
```

The API listens at `http://localhost:3000`. Check `http://localhost:3000/api/health` and `http://localhost:3000/api/health/database`.

### 3. Run the mobile app

Follow [mobile setup and testing](mobile/README.md). The Android emulator uses `http://10.0.2.2:3000/api` to reach the API on the development computer. A physical device needs a reachable computer address; see the mobile README.

## Backend checks

From `backend/`:

```powershell
npm test
npm run build
```
