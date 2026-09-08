CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE "users" (
    "id" BIGSERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "activities" (
    "id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "activity_type" TEXT NOT NULL,
    "distance" DECIMAL(10,2) NOT NULL,
    "duration" INTEGER NOT NULL,
    "pace" DECIMAL(10,2),
    "speed" DECIMAL(10,2),
    "average_heart_rate" INTEGER,
    "maximum_heart_rate" INTEGER,
    "calories" DECIMAL(10,2),
    "started_at" TIMESTAMP(3) NOT NULL,
    "completed_at" TIMESTAMP(3) NOT NULL,
    "route_data" JSONB,
    "gps_data" JSONB,
    CONSTRAINT "activities_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "activity_splits" (
    "id" BIGSERIAL NOT NULL,
    "activity_id" BIGINT NOT NULL,
    "kilometer" INTEGER NOT NULL,
    "time_seconds" INTEGER NOT NULL,
    CONSTRAINT "activity_splits_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "routes" (
    "id" BIGSERIAL NOT NULL,
    "user_id" BIGINT,
    "activity_type" TEXT NOT NULL,
    "distance" DECIMAL(10,2) NOT NULL,
    "duration" INTEGER,
    "score" DECIMAL(5,2),
    "route_data" JSONB NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "routes_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "users_email_key" ON "users"("email");
CREATE UNIQUE INDEX "activity_splits_activity_id_kilometer_key" ON "activity_splits"("activity_id", "kilometer");
CREATE INDEX "activities_user_id_idx" ON "activities"("user_id");
CREATE INDEX "activity_splits_activity_id_idx" ON "activity_splits"("activity_id");
CREATE INDEX "routes_user_id_idx" ON "routes"("user_id");

ALTER TABLE "activities" ADD CONSTRAINT "activities_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "activity_splits" ADD CONSTRAINT "activity_splits_activity_id_fkey" FOREIGN KEY ("activity_id") REFERENCES "activities"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "routes" ADD CONSTRAINT "routes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
