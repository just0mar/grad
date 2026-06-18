-- ============================================================
-- 031: Add bio and profile image fields to users
-- ============================================================

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS bio TEXT,
    ADD COLUMN IF NOT EXISTS profile_image_url VARCHAR(500);
