ALTER TABLE "tbl_users"
ADD COLUMN "height_cm" DECIMAL(5, 2),
ADD COLUMN "weight_kg" DECIMAL(6, 2);

ALTER TABLE "activities"
ADD COLUMN "idempotency_key" TEXT;

ALTER TABLE "activities"
ADD COLUMN "calorie_met_code" TEXT,
ADD COLUMN "calorie_met_value" DECIMAL(5, 2),
ADD COLUMN "calorie_weight_kg" DECIMAL(6, 2),
ADD COLUMN "calorie_duration_minutes" DECIMAL(10, 6),
ADD COLUMN "calorie_method_version" TEXT;

CREATE UNIQUE INDEX "activities_user_id_idempotency_key_key"
ON "activities"("user_id", "idempotency_key");
