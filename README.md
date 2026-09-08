# PathCraft

PathCraft is a capstone project that generates personalized outdoor routes for walking, jogging, running, and cycling using route data, geographic features, and recommendation logic.

## Architecture

- Mobile app: Flutter
- Backend: Node.js + Express + TypeScript
- Database: PostgreSQL + PostGIS
- Routing: OSRM
- AI: Python recommendation service

## Requirements

Install the following before running PathCraft:

- Git
- Node.js 20 or later and npm
- Flutter SDK and Dart SDK
- Python 3.12 or later
- PostgreSQL with the PostGIS extension, or a Supabase PostgreSQL project with PostGIS enabled
- Android Studio and an Android emulator or physical Android device for mobile testing

Docker is not required for local development.

Check the main tools with:

```powershell
git --version
node --version
npm --version
flutter --version
python --version
```

## Environment setup

Create a `.env` file in the repository root. Do not commit this file. It must contain:

```env
PORT=3000
NODE_ENV=development
JWT_SECRET=replace_with_a_long_random_secret
DATABASE_URL="postgresql://USER:PASSWORD@HOST:6543/postgres?pgbouncer=true&connection_limit=1"
DIRECT_URL="postgresql://USER:PASSWORD@HOST:5432/postgres"
OSRM_URL=http://localhost:5000
AI_SERVICE_URL=http://localhost:8000
```

For Supabase, copy the pooled connection into `DATABASE_URL` and the direct
connection into `DIRECT_URL` from Supabase Dashboard > Connect. Enable the
`postgis` extension in Supabase before running migrations. URL-encode special
characters in the database password.

## Install dependencies

From the repository root, run each section in a separate terminal when you want
all services running at the same time.

### Backend

```powershell
cd backend
npm install
npx prisma generate
npx prisma migrate deploy
```

### AI service

```powershell
cd ai
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

If PowerShell blocks activation, run the commands from Command Prompt instead:

```cmd
ai\.venv\Scripts\activate.bat
```

### Flutter mobile app

```powershell
cd mobile
flutter pub get
flutter doctor
```

## Run the system

Start the backend:

```powershell
cd backend
npm run dev
```

The backend runs at `http://localhost:3000`.

Start the AI service in another terminal:

```powershell
cd ai
.\.venv\Scripts\Activate.ps1
python main.py
```

The AI service runs at `http://localhost:8000`.

Start the Flutter app with an emulator or device running:

```powershell
cd mobile
flutter devices
flutter run
```

When using an Android emulator, the backend address is usually
`http://10.0.2.2:3000` from the emulator instead of `http://localhost:3000`.

## Verify the setup

Check the backend:

```powershell
Invoke-WebRequest http://localhost:3000/api/health
Invoke-WebRequest http://localhost:3000/api/health/database
```

Check the AI service:

```powershell
Invoke-WebRequest http://localhost:8000/health
```

Verify Prisma CRUD using disposable test data:

```powershell
cd backend
npm run verify:crud
```

Run backend tests with:

```powershell
cd backend
npm test
```

## Activity API

After login, send the returned JWT as `Authorization: Bearer <token>`.

- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/activities` returns only the authenticated user's activities.
- `POST /api/activities` creates an activity for the authenticated user; the
	request cannot choose another `userId`.

Distance is submitted in meters and returned as `distanceKm`. Pace is stored in
seconds per kilometer and returned as `averagePaceMinPerKm`. Heart-rate fields
are nullable and are omitted from neither storage nor meaning when no device
data is available. GPS points and route geometry are JSON fields; kilometer
splits are relational rows in `activity_splits`.

## Project structure

- `mobile/`: Flutter application
- `backend/`: Express, TypeScript, Prisma, authentication, and REST API
- `ai/`: Python recommendation service
- `backend/prisma/`: Prisma schema and migrations
- `docs/`: project documentation

## Phase 0

This repository is being created incrementally. The environment was audited before scaffolding.
