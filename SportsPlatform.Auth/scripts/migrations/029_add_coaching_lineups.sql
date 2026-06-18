CREATE TABLE IF NOT EXISTS public.coaching_lineup (
    lineup_id uuid PRIMARY KEY,
    team_id uuid NOT NULL REFERENCES public.team(team_id) ON DELETE CASCADE,
    event_id uuid NULL REFERENCES public.event(event_id) ON DELETE SET NULL,
    season_id uuid NULL REFERENCES public.season(season_id) ON DELETE SET NULL,
    created_by uuid NOT NULL REFERENCES public.users(user_id) ON DELETE RESTRICT,
    title varchar(200) NOT NULL,
    formation varchar(50) NULL,
    game_model text NULL,
    tactical_notes text NULL,
    visibility public.plan_visibility NOT NULL DEFAULT 'Draft',
    deleted_at timestamp with time zone NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.coaching_lineup_player (
    lineup_player_id uuid PRIMARY KEY,
    lineup_id uuid NOT NULL REFERENCES public.coaching_lineup(lineup_id) ON DELETE CASCADE,
    player_user_id uuid NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    position varchar(80) NOT NULL,
    unit varchar(40) NOT NULL DEFAULT 'Starting',
    sort_order integer NOT NULL DEFAULT 0,
    instructions text NULL,
    CONSTRAINT uq_coaching_lineup_player UNIQUE (lineup_id, player_user_id)
);

CREATE INDEX IF NOT EXISTS ix_coaching_lineup_team_event ON public.coaching_lineup(team_id, event_id);
CREATE INDEX IF NOT EXISTS ix_coaching_lineup_visibility ON public.coaching_lineup(team_id, visibility) WHERE deleted_at IS NULL;
