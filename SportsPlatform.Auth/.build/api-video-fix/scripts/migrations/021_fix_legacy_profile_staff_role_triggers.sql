-- ============================================================
-- 021: Replace legacy role-check triggers after user_role removal
-- ============================================================

-- Older database snapshots created trigger functions that checked public.user_role
-- before inserting player_profile/team_staff rows. The v8 model stores team roles
-- in public.team_membership, and public.user_role is intentionally removed.

DO $$
BEGIN
    IF to_regclass('public.player_profile') IS NOT NULL THEN
        EXECUTE 'DROP TRIGGER IF EXISTS trg_player_role_check ON public.player_profile';
    END IF;

    IF to_regclass('public.team_staff') IS NOT NULL THEN
        EXECUTE 'DROP TRIGGER IF EXISTS trg_staff_role_check ON public.team_staff';
    END IF;
END $$;

DROP FUNCTION IF EXISTS public.check_staff_has_role();

CREATE OR REPLACE FUNCTION public.check_player_has_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.team_membership tm
        WHERE tm.user_id = NEW.user_id
          AND tm.role = 'Player'
          AND tm.status = 'Active'
    ) THEN
        RAISE EXCEPTION 'User % needs an active Player team membership before a player_profile can be created',
            NEW.user_id;
    END IF;

    RETURN NEW;
END;
$$;

DO $$
BEGIN
    IF to_regclass('public.player_profile') IS NOT NULL THEN
        EXECUTE '
            CREATE CONSTRAINT TRIGGER trg_player_role_check
            AFTER INSERT ON public.player_profile
            DEFERRABLE INITIALLY DEFERRED
            FOR EACH ROW
            EXECUTE FUNCTION public.check_player_has_role()
        ';
    END IF;
END $$;
