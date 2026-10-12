# Local PostgreSQL Setup

Karipa uses PostgreSQL installed directly on the development machine. Docker is not required.

## Required configuration

1. Install PostgreSQL 16 locally and ensure the PostgreSQL service is running.
2. Install PostGIS for the same PostgreSQL major version using StackBuilder or the PostGIS Windows installer.
3. Create a database named `karipa`.
4. Enable PostGIS in that database:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
SELECT PostGIS_Version();
```

5. Copy `backend/.env.example` to `backend/.env` and set `DATABASE_URL` to the local credentials.
6. From `backend`, generate the client and apply the checked-in migrations:

```powershell
npm install
npx prisma generate
npx prisma migrate dev
```

The migrations create the initial users, activities, and routes tables, then add email-verification fields and activity splits. The migration command is intentionally not run until local credentials and PostGIS are configured. Do not use `prisma migrate reset`.

## Verification

```powershell
npm run verify:crud
npm run dev
```

Then request `http://localhost:3000/api/health/database`. The endpoint executes `SELECT 1` through Prisma; it does not report a connection as healthy without querying PostgreSQL.
