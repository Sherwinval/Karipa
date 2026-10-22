DO $$
BEGIN
    IF to_regclass('public.tbl_users') IS NOT NULL THEN
        IF to_regclass('public.users') IS NOT NULL THEN
            RAISE EXCEPTION 'Both public.users and public.tbl_users exist; refusing to guess which table is authoritative';
        END IF;
    ELSIF to_regclass('public.users') IS NOT NULL THEN
        ALTER TABLE public."users" RENAME TO "tbl_users";
    ELSE
        RAISE EXCEPTION 'Neither public.users nor public.tbl_users exists; cannot rename user table';
    END IF;
END
$$;
