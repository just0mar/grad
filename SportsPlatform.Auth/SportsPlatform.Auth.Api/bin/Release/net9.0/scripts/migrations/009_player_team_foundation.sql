-- ============================================================
-- 009: Player team foundation for current-team tracking
-- ============================================================

CREATE TABLE IF NOT EXISTS public.player_team (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id uuid NOT NULL REFERENCES public.player_profile(player_id) ON DELETE CASCADE,
    team_id uuid NOT NULL REFERENCES public.team(team_id) ON DELETE CASCADE,
    joined_date date NOT NULL DEFAULT current_date,
    left_date date,
    is_current boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_player_team_team ON public.player_team (team_id);
CREATE INDEX IF NOT EXISTS idx_player_team_player ON public.player_team (player_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_player_team_current ON public.player_team (player_id) WHERE (is_current = true);
