# PathCraft

PathCraft is a capstone project that generates personalized outdoor routes for walking, jogging, running, and cycling using route data, geographic features, and recommendation logic.

## Architecture

Default architecture chosen for this capstone build:

- **Mobile app:** Flutter + Dart + Material 3 + Google Fonts
- **Backend:** Node.js + Express + TypeScript
- **Database:** Supabase Postgres with PostGIS + RLS migration files tracked in the repo
- **Routing:** self-hosted OSRM service, with route candidates approximating target distances via waypoint loops and out-and-back generation
- **AI Service:** Python + FastAPI + Gemini API with deterministic fallback ranking
- **Auth:** Supabase Auth is the recommended default for this project; custom JWT remains an option if required for the panel

This repo keeps the app and service boundaries modular so route generation, route evaluation, and AI ranking remain separate components.

---

## Prerequisites Check

Before running PathCraft, ensure you have the following installed:

- **Git**
- **Node.js** (v20 or higher) and **npm**
- **Python** (v3.12 or higher)
- **Flutter SDK** and **Dart SDK** (v3.3.0 or higher)
- **PostgreSQL** with PostGIS extension (or a Supabase PostgreSQL project with PostGIS enabled)
- **Android Studio** (with an emulator or connected physical Android device)

Check installed versions:

```powershell
git --version
node --version
npm --version
flutter --version
python --version
```

---

## Step-by-Step Setup & How to Run

### Step 1: Environment Setup (`.env`)

Create a `.env` file in the repository root (or copy from `.env.example`). Do not commit this file.

```env
PORT=3000
NODE_ENV=development
JWT_SECRET=replace_with_a_long_random_secret

# Supabase config
DATABASE_URL="postgresql://USER:PASSWORD@HOST:6543/postgres?pgbouncer=true"
DIRECT_URL="postgresql://USER:PASSWORD@HOST:5432/postgres"

# Services
OSRM_URL=http://localhost:5000
AI_SERVICE_URL=http://localhost:8000
```

> **Optional Docker setup:** If running PostgreSQL locally via Docker instead of Supabase:
> ```powershell
> docker compose up -d
> ```

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

### Step 3: Set Up & Run AI Service

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

### Step 4: Run Flutter Mobile App

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
- **AI Service Health:** `http://localhost:8000/health`

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
- `ai/`: Python recommendation service
- `backend/prisma/`: Database schema & migrations
- `docs/`: Additional setup and design documentation
