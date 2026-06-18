CREATE TABLE IF NOT EXISTS public.match_stats (
    match_stats_id uuid PRIMARY KEY,
    team_id uuid NOT NULL REFERENCES public.team(team_id) ON DELETE CASCADE,
    event_id uuid NOT NULL REFERENCES public.event(event_id) ON DELETE CASCADE,
    season_id uuid NOT NULL REFERENCES public.season(season_id) ON DELETE RESTRICT,
    recorded_by uuid NOT NULL REFERENCES public.users(user_id) ON DELETE RESTRICT,
    opponent_name varchar(200) NULL,
    team_score integer NULL,
    opponent_score integer NULL,
    result varchar(20) NULL,
    venue varchar(200) NULL,
    competition_name varchar(200) NULL,
    possession_percent numeric(5, 2) NULL,
    total_goals integer NULL,
    total_assists integer NULL,
    shots_on_target integer NULL,
    total_shots integer NULL,
    passes_completed integer NULL,
    passes_attempted integer NULL,
    pass_accuracy numeric(5, 2) NULL,
    tackles integer NULL,
    interceptions integer NULL,
    yellow_cards integer NULL,
    red_cards integer NULL,
    notes text NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT uq_match_stats_team_event UNIQUE (team_id, event_id),
    CONSTRAINT ck_match_stats_result CHECK (result IS NULL OR result IN ('Win', 'Draw', 'Loss'))
);

CREATE TABLE IF NOT EXISTS public.player_match_stats (
    player_match_stats_id uuid PRIMARY KEY,
    match_stats_id uuid NOT NULL REFERENCES public.match_stats(match_stats_id) ON DELETE CASCADE,
    team_id uuid NOT NULL REFERENCES public.team(team_id) ON DELETE CASCADE,
    event_id uuid NOT NULL REFERENCES public.event(event_id) ON DELETE CASCADE,
    season_id uuid NOT NULL REFERENCES public.season(season_id) ON DELETE RESTRICT,
    player_user_id uuid NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    minutes_played integer NULL,
    goals integer NULL,
    assists integer NULL,
    shots_on_target integer NULL,
    total_shots integer NULL,
    passes_completed integer NULL,
    passes_attempted integer NULL,
    pass_accuracy numeric(5, 2) NULL,
    tackles integer NULL,
    interceptions integer NULL,
    yellow_cards integer NULL,
    red_cards integer NULL,
    rating numeric(4, 2) NULL,
    notes text NULL,
    CONSTRAINT uq_player_match_stats_match_player UNIQUE (match_stats_id, player_user_id)
);

CREATE INDEX IF NOT EXISTS ix_match_stats_team_season ON public.match_stats(team_id, season_id);
CREATE INDEX IF NOT EXISTS ix_player_match_stats_team_player ON public.player_match_stats(team_id, player_user_id);
CREATE INDEX IF NOT EXISTS ix_player_match_stats_team_event ON public.player_match_stats(team_id, event_id);

DO $$
BEGIN
    IF to_regclass('public.match_analysis_document') IS NOT NULL THEN
        DELETE FROM public.match_analysis_document;
    END IF;

    IF to_regclass('public.match_lineup_analysis') IS NOT NULL THEN
        DELETE FROM public.match_lineup_analysis;
    END IF;

    IF to_regclass('public.match_analysis_report') IS NOT NULL THEN
        DELETE FROM public.match_analysis_report;
    END IF;
END $$;
