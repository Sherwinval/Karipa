# Karipa

Karipa is a capstone project that generates personalized outdoor routes for walking, jogging, running, and cycling using route data, geographic features, and recommendation logic.

## Architecture

Selected proposed architecture for this capstone build:

- **Mobile app:** Flutter + Dart + Material 3 + Google Fonts
- **Backend:** Node.js + Express + TypeScript
- **Database:** Supabase Postgres with PostGIS + RLS migration files tracked in the repo
- **Maps and routing:** Google Maps for Flutter displays routes; the Google Maps Routes API generates network routes. Candidate distance uses the provider's returned route distance. No maximum deviation is assumed by default; `ROUTE_MAX_DISTANCE_DEVIATION_KM` remains optional pending approval.
- **AI ranking:** Gemini route ranking is enabled by default and is invoked only for candidates tied on both actual distance deviation and supported preference score. Deterministic ranking handles non-tied candidates and is the fallback when AI is explicitly disabled, unavailable, or returns invalid IDs.
- **Auth:** Express JWT authentication. Profile measurements and activity records are scoped to the authenticated account.
- **Provider limitation:** Google Maps cycling-route availability must be verified for the project region. The app does not silently use another provider when Google cannot return cycling routes.
- **Provider content:** Google route geometry is displayed on Google Maps and kept transient for route selection/tracking. Newly saved route/activity database records do not include Google-derived route geometry; user GPS tracks remain separate user data.

### Current measurement and tracking behavior

- Height and weight are optional values users can enter during registration or later in their profile, stored canonically in centimeters and kilograms. The profile lets users choose metric or imperial display units (cm/kg/km or decimal ft/lb/mi); changing the preference does not change saved measurements or activity records. Both measurements must be positive finite numbers; adviser-approved plausibility limits have not been specified. Height is not used in the calorie equation.
- Route and activity distances, pace, and speed follow the selected display-unit preference; API and persisted activity values remain in canonical metric units.
- Calorie values are provisional gross-session estimates using the capstone's published MET examples and `MET × weight (kg) × counted minutes / 60`. The mapping remains subject to adviser review. Jogging and running estimates are available only when their documented categories can be matched to measured GPS movement; walking surface/grade and leisure-cycling context are not verified by current route data, so those estimates remain unavailable.
- Activity distance is GPS-recorded and is never replaced with planned-route distance. Route progress is not map-matched, so remaining-route and finish-time estimates are shown as unavailable.
- Pause/resume is supported. Background tracking and offline synchronization are not supported.
- Activity recording supports Plan a Route and Free Recording. Finishing opens a review screen; activities are persisted only after the user saves. Active duration excludes pauses, total elapsed includes them, and actual GPS distance is saved separately from an optional route target. Existing records default to Plan a Route; apply the additive `20261021_free_recording` migration along with other pending migrations before deploying this API.
- An unsaved review session remains in app memory; if the app process is terminated before save, it cannot currently be recovered. Leaving the foreground pauses recording, and the user must resume manually. Current API validation permits zero-distance, zero-duration activities; no minimum evidence rule is enforced because that specification remains unresolved. Existing GPS filtering rejects fixes older than 15 seconds or with non-positive timestamps, rejects observed jumps above 35 m/s, excludes fixes with accuracy above 30 m from activity distance, ignores segments longer than 30 seconds, and only adds segments of at least 1.5 m. Pace/speed is unavailable below 50 m or 5 active seconds. These existing rules need adviser/product approval and are not claimed as finalized GPS/timing specifications.
- New profile, activity idempotency, calorie-basis, and recording-mode columns are additive. Apply pending migrations with `npx prisma migrate deploy`; do not reset or recreate the database.
- Google-derived route geometry is used in memory for the active route flow and is not written into new saved-route or activity records. Activity records may retain non-geometry route summary metadata. Previously saved records are left unchanged.
- The weekly leaderboard is available from the Home bottom tab. It ranks verified members with a positive-distance activity by saved distance for the current Sunday-to-Saturday calendar week, resetting at midnight Sunday in Philippine time (Asia/Manila). It shows at most the top 50 plus the signed-in user when outside that range and exposes only display names and aggregate distance (no activity details). Resetting the leaderboard does not delete saved activity history.
- The leaderboard aggregates each saved activity's recorded distance. Current eligibility is verified account plus a positive saved distance during the current calendar week; all activity types and recording modes are included. There is no separate leaderboard opt-in in the current implementation.

---

## Prerequisites Check

Before running Karipa, ensure you have the following installed:

- **Git**
- **Node.js** (v20 or higher) and **npm**
- **Flutter SDK** and **Dart SDK** (v3.3.0 or higher)
- **PostgreSQL** with PostGIS extension (or a Supabase PostgreSQL project with PostGIS enabled)
- **Android Studio** (with an emulator or connected physical Android device)

Check installed versions:

```powershell
git --version
node --version
npm --version
flutter --version
```

---

## Step-by-Step Setup & How to Run

### Step 1: Environment Setup (`backend/.env`)

Copy `backend/.env.example` to `backend/.env` and replace its placeholders. Do not commit the real file.

```env
PORT=3000
NODE_ENV=development
JWT_SECRET=replace_with_a_long_random_secret

# Database config
DATABASE_URL="postgresql://USER:PASSWORD@HOST:6543/postgres?pgbouncer=true"
DIRECT_URL="postgresql://USER:PASSWORD@HOST:5432/postgres"

# Google Maps Routes API and AI-assisted ranking (enabled by default)
GOOGLE_MAPS_ROUTES_API_KEY=your-server-side-routes-api-key
GEMINI_API_KEY=your-gemini-api-key
AI_ROUTE_RANKING_ENABLED=true
# Set AI_ROUTE_RANKING_ENABLED=false to use deterministic ranking only.
ROUTE_MAX_DISTANCE_DEVIATION_KM=
```

> **Optional Docker setup:** If running PostgreSQL locally via Docker instead of Supabase:
> ```powershell
> docker compose up -d
> ```

---

### Step 1a: Configure Google Maps Platform

Create separate, restricted API keys in the same Google Cloud project:

- **Backend key:** enable Routes API and set `GOOGLE_MAPS_ROUTES_API_KEY` in `backend/.env`. Keep this server-side key private and restrict it to the Routes API and the backend's hosting/network policy.
- **Android key:** enable Maps SDK for Android and expose `GOOGLE_MAPS_ANDROID_API_KEY` to the Gradle process. Restrict it to the Android app id and signing certificate.
- **iOS key:** enable Maps SDK for iOS and create `mobile/ios/Flutter/MapsSecrets.xcconfig` containing `GOOGLE_MAPS_IOS_API_KEY=your-ios-sdk-key`. This file is git-ignored. Restrict the key to the iOS bundle id and Maps SDK for iOS.

Example for a PowerShell session:

```powershell
$env:GOOGLE_MAPS_ANDROID_API_KEY = "your-android-sdk-key"
```

Google Maps Platform billing and the corresponding APIs must be enabled. Android/iOS SDK keys are included in mobile builds, so protect them with application restrictions; never use the server-side Routes API key as a mobile SDK key. Route candidate generation makes up to six billable Routes API requests per planning attempt. Google bicycle-routing coverage in the Philippines is not confirmed; when Google returns no cycling route, Karipa reports that result rather than switching providers. Cycling activity tracking remains available.

The Google Maps Flutter plugin requires Android API level 24 or later. The Android minimum SDK is set accordingly.

---

### Step 2: Set Up & Run Backend Service

Open a new terminal:

1. Navigate to `backend`:
   ```powershell
   cd backend
   ```
2. Install dependencies:
   ```powershell
   npm install
   ```
3. Generate Prisma client & apply database migrations:
   ```powershell
   npx prisma generate
   npx prisma migrate deploy
   ```
4. Start the backend in development mode:
   ```powershell
   npm run dev
   ```
   *The backend will run at `http://localhost:3000`.*

---

### Legacy Python Scorer (not used for updated route ranking)

This standalone scorer implements the previous ranking behavior and is not used by the updated application. Do not start it for route recommendations; the backend's validated Gemini tie-break or deterministic fallback is the current flow.

Open a second terminal:

1. Navigate to `ai`:
   ```powershell
   cd ai
   ```
2. Create and activate a Python virtual environment:
   - **PowerShell:**
     ```powershell
     python -m venv .venv
     .\.venv\Scripts\Activate.ps1
     ```
   - **Command Prompt (CMD):**
     ```cmd
     python -m venv .venv
     .venv\Scripts\activate.bat
     ```
3. Install required Python packages:
   ```powershell
   pip install -r requirements.txt
   ```
4. Start the AI service:
   ```powershell
   python main.py
   ```
   *The AI service will run at `http://localhost:8000`.*

---

### Step 3: Run Flutter Mobile App

Open a third terminal:

1. Launch your Android Emulator in Android Studio or connect a physical device.
2. Navigate to `mobile`:
   ```powershell
   cd mobile
   ```
3. Fetch dependencies:
   ```powershell
   flutter pub get
   ```
4. Verify connected devices:
   ```powershell
   flutter devices
   ```
5. Run the mobile application:
   ```powershell
   flutter run
   ```

> **Note for Android Emulator:** The backend address accessed from the emulator is `http://10.0.2.2:3000` instead of `http://localhost:3000`.
>
> **Physical Android device:** A phone cannot use the emulator-only `10.0.2.2` address. Connect the phone and development computer to the same Wi-Fi network, find the computer's LAN IPv4 address (for example, `192.168.1.25`), then start the app with that address:
> ```powershell
> flutter run --dart-define=API_BASE_URL=http://192.168.1.25:3000/api
> ```
> Replace the example address with the computer's current LAN IP. Check `http://<computer-LAN-IP>:3000/api/health` in the phone's browser first; if it cannot load, allow inbound TCP port 3000 through the computer's firewall and check that the Wi-Fi network allows device-to-device connections. The API override applies to all Flutter API calls. Plain HTTP is permitted only in Android debug builds; use HTTPS for release builds.
> 
> **Tip - Setting Emulator Location:** By default, Android Emulators report a fixed default location. To automatically set the emulator's GPS location based on where you are (or a specific city/coordinates), run the included helper script in the project root:
> ```powershell
> # Automatically detect and set emulator location via IP geolocation
> .\set_emulator_location.ps1
> 
> # Or specify a target city
> .\set_emulator_location.ps1 -City "New York"
> 
> # Or specify custom coordinates (latitude & longitude)
> .\set_emulator_location.ps1 -Latitude 37.7749 -Longitude -122.4194
> ```

---

## Verification & Health Checks

Verify services are running properly:

- **Backend Health:** `http://localhost:3000/api/health`
- **Database Connection Health:** `http://localhost:3000/api/health/database`
- **Gemini integration health:** `http://localhost:3000/api/ai/health` (backend, when `GEMINI_API_KEY` is configured)

**Verify Prisma CRUD using disposable test data:**
```powershell
cd backend
npm run verify:crud
```

**Run Backend Unit Tests:**
```powershell
cd backend
npm test
```

---

## Activity API Overview

After login, include the returned JWT in request headers as `Authorization: Bearer <token>`.

- `POST /api/auth/register` - Register a new user
- `POST /api/auth/login` - User login
- `GET /api/activities` - Fetch authenticated user's activities
- `POST /api/activities` - Record a new activity

---

## Project Structure

- `mobile/`: Flutter mobile application
- `backend/`: Express, TypeScript, Prisma REST API
- `ai/`: legacy standalone Python route scorer; not used for updated recommendations
- `backend/prisma/`: Database schema & migrations
- `docs/`: Additional setup and design documentation
