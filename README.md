# PathCraft

PathCraft is a capstone project that generates personalized outdoor routes for walking, jogging, running, and cycling using route data, geographic features, and recommendation logic.

## Architecture

- Mobile app: Flutter
- Backend: Node.js + Express + TypeScript
- Database: PostgreSQL + PostGIS
- Routing: OSRM
- AI: Python recommendation service

## Local development

PathCraft uses PostgreSQL installed directly on the development machine. Docker is
not required for local development. Configure `DATABASE_URL` in `backend/.env`,
then run the backend with `npm run dev` from `backend`.

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

## Phase 0

This repository is being created incrementally. The environment was audited before scaffolding.
