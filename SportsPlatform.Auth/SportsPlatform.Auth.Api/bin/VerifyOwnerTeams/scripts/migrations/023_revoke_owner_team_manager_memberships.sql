-- ============================================================
-- 023: Club owners do not need team-level TeamManager rows
-- ============================================================

UPDATE public.team_membership tm
SET
    status = 'Revoked'::public.membership_status,
    updated_at = NOW()
FROM public.team t
JOIN public.club c ON c.club_id = t.club_id
WHERE tm.team_id = t.team_id
  AND tm.user_id = c.created_by
  AND tm.role = 'TeamManager'::public.role_name_type
  AND tm.status = 'Active'::public.membership_status
  AND t.deleted_at IS NULL
  AND c.deleted_at IS NULL;
