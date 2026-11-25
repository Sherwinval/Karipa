ALTER TABLE "tbl_users" ADD COLUMN "session_version" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE "password_recovery" (
  "id" UUID PRIMARY KEY,
  "email_hash" TEXT NOT NULL UNIQUE,
  "user_id" BIGINT REFERENCES "tbl_users"("id") ON DELETE CASCADE,
  "otp_hash" TEXT,
  "issued_at" TIMESTAMP(3) NOT NULL,
  "expires_at" TIMESTAMP(3) NOT NULL,
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "reset_hash" TEXT UNIQUE,
  "reset_expires_at" TIMESTAMP(3),
  "consumed_at" TIMESTAMP(3)
);
CREATE INDEX "password_recovery_user_id_idx" ON "password_recovery"("user_id");
CREATE TABLE "recovery_rate_limits" (
  "key" TEXT PRIMARY KEY,
  "count" INTEGER NOT NULL,
  "expires_at" TIMESTAMP(3) NOT NULL
);
