-- ============================================================
-- 025: Backfill player profiles for active player memberships
-- ============================================================

UPDATE public.player_profile pp
SET
    deleted_at = NULL,
    updated_at = NOW()
FROM public.team_membership tm
JOIN public.team t ON t.team_id = tm.team_id
WHERE pp.user_id = tm.user_id
  AND tm.role = 'Player'::public.role_name_type
  AND tm.status = 'Active'::public.membership_status
  AND t.deleted_at IS NULL
  AND pp.deleted_at IS NOT NULL;

INSERT INTO public.player_profile (
    player_id,
    user_id,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),
    tm.user_id,
    NOW(),
    NOW()
FROM public.team_membership tm
JOIN public.team t ON t.team_id = tm.team_id
WHERE tm.role = 'Player'::public.role_name_type
  AND tm.status = 'Active'::public.membership_status
  AND t.deleted_at IS NULL
  AND NOT EXISTS (
      SELECT 1
      FROM public.player_profile pp
      WHERE pp.user_id = tm.user_id
  );

INSERT INTO public.player_team (
    id,
    player_id,
    team_id,
    joined_date,
    is_current,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),
    pp.player_id,
    tm.team_id,
    COALESCE(tm.joined_at::date, CURRENT_DATE),
    TRUE,
    NOW(),
    NOW()
FROM public.team_membership tm
JOIN public.team t ON t.team_id = tm.team_id
JOIN public.player_profile pp ON pp.user_id = tm.user_id
WHERE tm.role = 'Player'::public.role_name_type
  AND tm.status = 'Active'::public.membership_status
  AND t.deleted_at IS NULL
  AND pp.deleted_at IS NULL
  AND NOT EXISTS (
      SELECT 1
      FROM public.player_team pt
      WHERE pt.player_id = pp.player_id
        AND pt.team_id = tm.team_id
        AND pt.is_current = TRUE
  );
