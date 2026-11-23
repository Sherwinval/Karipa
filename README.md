# Karipa

Karipa is a mobile route-planning and activity-tracking app for walking, jogging, running, and cycling. It pairs a Flutter app with a TypeScript API and PostgreSQL/PostGIS database.

## Current features

- Plan routes using Valhalla routing and OpenStreetMap maps.
- Register, sign in, verify email, and manage a profile.
- Track planned routes or record an activity without a route; review and save recordings to activity history.
- View a weekly distance leaderboard.
- Use metric or imperial units and light or dark appearance.

Route candidates use Valhalla's OSM routing graph for road-following geometry and authoritative distance. The backend rejects routes farther than 0.5 km from the requested target by default; set `ROUTE_MAX_DISTANCE_DEVIATION_KM` to a positive value to change the tolerance. Valhalla applies supported activity-specific costing options, but OSM coverage and preference tags can be incomplete. Candidate geometry supplied directly by a client is rejected; use `POST /api/routes/generate` so geometry and distance are verified against Valhalla.

Groq is optional and runs server-side. The backend uses `openai/gpt-oss-20b` by default for structured preference interpretation, validated-candidate evaluation, and distance guidance; set `GROQ_MODEL` to change it, `GROQ_ENABLED=false` to disable all Groq assistance, or `AI_ROUTE_RANKING_ENABLED=false` to disable candidate evaluation only. Groq requests have a 5-second timeout and at most one retry on transient network/server failures. Invalid output, unavailable service, and missing configuration fall back to deterministic routing and ranking. The backend logs request latency, retries, errors, and reported token usage without logging prompts or credentials. Route geometry, access, and distance always come from Valhalla; the app never receives model-generated coordinates.

The Groq model page documents a 131,072-token context window and approximate throughput of 1,000 tokens/second for GPT-OSS 20B. Groq's public rate-limit table lists Developer-plan limits of 30 RPM, 1,000 RPD, 8,000 TPM, and 200,000 TPD for this model; the exact organization limits are available in the Groq account's Limits page and can differ. Calorie values are estimates. Activity recording currently requires the app to remain in the foreground; background tracking and offline synchronization are not supported.

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

Copy `backend/.env.example` to `backend/.env`, then set the database URLs and a secure `JWT_SECRET`. Configure a reachable Valhalla server using `VALHALLA_BASE_URL`. Groq-powered assistance is optional; set `GROQ_API_KEY` to enable it. Without a key, free-text notes are not interpreted and route ranking uses deterministic ordering. SMTP settings are optional for email delivery.

From the repository root, run:

```powershell
Set-Location backend
npm install
npx prisma generate
npx prisma migrate dev
npm run dev
```

`npm run dev` starts the API at `http://localhost:3000` and attempts to start a Cloudflare Quick Tunnel when `cloudflared` is installed. The generated public URL is printed and saved in the ignored `backend/.tunnel-url` file. Quick Tunnel URLs change when restarted.

For automatic URL discovery by an already-installed Flutter app, configure the stable `workers.dev` discovery Worker once and set its endpoint and publish secret in `backend/.env`. See [the tunnel discovery setup](backend/tunnel-discovery/README.md). Build the mobile app with that stable Worker endpoint once; subsequent Quick Tunnel restarts do not require APK rebuilds.

Check `http://localhost:3000/api/health` and `http://localhost:3000/api/health/database` for local backend health.

### 3. Run the mobile app

Follow [mobile setup and testing](mobile/README.md). The Android emulator uses `http://10.0.2.2:3000/api` to reach the API on the development computer. A physical device needs a reachable computer address; see the mobile README.

## Backend checks

From `backend/`:

```powershell
npm test
npm run build
```
