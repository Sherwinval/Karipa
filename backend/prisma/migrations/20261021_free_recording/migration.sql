ALTER TABLE "activities"
ADD COLUMN "recording_mode" TEXT NOT NULL DEFAULT 'plan_route',
ADD COLUMN "total_elapsed_duration" INTEGER,
ADD COLUMN "target_distance" DECIMAL(10, 2);
