-- Migrate game_video from a link-only model to server-stored file uploads.
-- Idempotent: a no-op on fresh databases where 044 already created the new
-- schema; brings older databases (with a `url` column) up to date.

ALTER TABLE public.game_video
    ADD COLUMN IF NOT EXISTS file_name          varchar(300) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS original_file_name varchar(300) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS content_type       varchar(150) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS file_size          bigint NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS storage_path       text NOT NULL DEFAULT '';

-- The old external-link column is no longer used.
ALTER TABLE public.game_video
    DROP COLUMN IF EXISTS url;
