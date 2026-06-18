-- ============================================================
-- 008: Player invitation requirements and player profile support
-- ============================================================

ALTER TABLE public.invitation
    ADD COLUMN IF NOT EXISTS player_position varchar(50),
    ADD COLUMN IF NOT EXISTS jersey_number integer;

CREATE TABLE IF NOT EXISTS public.player_profile (
    player_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL UNIQUE REFERENCES public.users(user_id) ON DELETE CASCADE,
    position varchar(50),
    jersey_number integer,
    height numeric(5,2),
    weight numeric(5,2),
    deleted_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.player_profile
    ADD COLUMN IF NOT EXISTS jersey_number integer;
