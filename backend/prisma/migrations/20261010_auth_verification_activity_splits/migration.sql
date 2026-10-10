ALTER TABLE "users"
ADD COLUMN "is_verified" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "otp" TEXT,
ADD COLUMN "otp_expires_at" TIMESTAMP(3);

CREATE TABLE "activity_splits" (
    "id" BIGSERIAL NOT NULL,
    "activity_id" BIGINT NOT NULL,
    "kilometer" INTEGER NOT NULL,
    "time_seconds" INTEGER NOT NULL,
    CONSTRAINT "activity_splits_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "activity_splits_activity_id_kilometer_key"
ON "activity_splits"("activity_id", "kilometer");

CREATE INDEX "activity_splits_activity_id_idx"
ON "activity_splits"("activity_id");

ALTER TABLE "activity_splits"
ADD CONSTRAINT "activity_splits_activity_id_fkey"
FOREIGN KEY ("activity_id") REFERENCES "activities"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
