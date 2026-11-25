ALTER TABLE "tbl_users"
ADD COLUMN "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

CREATE OR REPLACE FUNCTION public.set_tbl_users_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;

CREATE TRIGGER tbl_users_set_updated_at
BEFORE UPDATE ON "tbl_users"
FOR EACH ROW
EXECUTE FUNCTION public.set_tbl_users_updated_at();
