-- ============================================================
-- 002: Create team_manager junction table + backfill
-- Supports many-to-many Team <-> Manager relationship
-- ============================================================

-- Step 1: Create the junction table
CREATE TABLE IF NOT EXISTS public.team_manager (
    team_id     UUID NOT NULL REFERENCES public.team(team_id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    assigned_by UUID,
    PRIMARY KEY (team_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_team_manager_user ON public.team_manager (user_id);

-- Step 2: Backfill from existing team.manager_user_id
INSERT INTO public.team_manager (team_id, user_id, assigned_at, assigned_by)
SELECT team_id, manager_user_id, COALESCE(created_at, NOW()), manager_user_id
FROM public.team
WHERE manager_user_id IS NOT NULL
  AND deleted_at IS NULL
ON CONFLICT (team_id, user_id) DO NOTHING;
