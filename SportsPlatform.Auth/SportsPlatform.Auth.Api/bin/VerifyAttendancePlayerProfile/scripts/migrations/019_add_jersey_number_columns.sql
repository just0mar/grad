-- ============================================================
-- 019: Ensure jersey_number columns exist
-- (covers the case where 008 was applied before jersey_number was added)
-- ============================================================

ALTER TABLE public.player_profile
    ADD COLUMN IF NOT EXISTS jersey_number integer;

ALTER TABLE public.invitation
    ADD COLUMN IF NOT EXISTS jersey_number integer;
