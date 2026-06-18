-- ============================================================
-- 016: Game statistics foundation
-- ============================================================

DO $$
DECLARE
    backup_name text;
BEGIN
    IF to_regclass('public.player_game_stats') IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM information_schema.columns
           WHERE table_schema = 'public'
             AND table_name = 'player_game_stats'
             AND column_name = 'stat_id'
       ) THEN
        backup_name := 'player_game_stats_legacy_backup';

        IF to_regclass('public.' || backup_name) IS NOT NULL THEN
            backup_name := 'player_game_stats_legacy_backup_' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS');
        END IF;

        EXECUTE format('ALTER TABLE public.player_game_stats RENAME TO %I', backup_name);
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.player_game_stats (
    stat_id uuid DEFAULT gen_random_uuid() NOT NULL,
    team_id uuid NOT NULL REFERENCES public.team(team_id) ON DELETE CASCADE,
    player_user_id uuid NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    event_id uuid NULL REFERENCES public.event(event_id) ON DELETE SET NULL,
    recorded_by uuid NOT NULL REFERENCES public.users(user_id) ON DELETE RESTRICT,
    match_date date NOT NULL,
    opponent_name varchar(200) NULL,
    minutes_played integer NULL,
    goals integer NULL,
    assists integer NULL,
    yellow_cards integer NULL,
    red_cards integer NULL,
    rating numeric(4,2) NULL,
    notes text NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_player_game_stats PRIMARY KEY (stat_id),
    CONSTRAINT chk_player_game_stats_non_negative CHECK (
        (minutes_played IS NULL OR minutes_played >= 0)
        AND (goals IS NULL OR goals >= 0)
        AND (assists IS NULL OR assists >= 0)
        AND (yellow_cards IS NULL OR yellow_cards >= 0)
        AND (red_cards IS NULL OR red_cards >= 0)
    ),
    CONSTRAINT chk_player_game_stats_rating CHECK (rating IS NULL OR (rating >= 0 AND rating <= 10))
);

ALTER TABLE public.player_game_stats
    ADD COLUMN IF NOT EXISTS stat_id uuid NOT NULL DEFAULT gen_random_uuid(),
    ADD COLUMN IF NOT EXISTS team_id uuid NULL,
    ADD COLUMN IF NOT EXISTS player_user_id uuid NULL,
    ADD COLUMN IF NOT EXISTS event_id uuid NULL,
    ADD COLUMN IF NOT EXISTS recorded_by uuid NULL,
    ADD COLUMN IF NOT EXISTS match_date date NOT NULL DEFAULT CURRENT_DATE,
    ADD COLUMN IF NOT EXISTS opponent_name varchar(200) NULL,
    ADD COLUMN IF NOT EXISTS minutes_played integer NULL,
    ADD COLUMN IF NOT EXISTS goals integer NULL,
    ADD COLUMN IF NOT EXISTS assists integer NULL,
    ADD COLUMN IF NOT EXISTS yellow_cards integer NULL,
    ADD COLUMN IF NOT EXISTS red_cards integer NULL,
    ADD COLUMN IF NOT EXISTS rating numeric(4,2) NULL,
    ADD COLUMN IF NOT EXISTS notes text NULL,
    ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'player_game_stats_team_id_fkey'
    ) THEN
        ALTER TABLE public.player_game_stats
            ADD CONSTRAINT player_game_stats_team_id_fkey
            FOREIGN KEY (team_id) REFERENCES public.team(team_id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'player_game_stats_player_user_id_fkey'
    ) THEN
        ALTER TABLE public.player_game_stats
            ADD CONSTRAINT player_game_stats_player_user_id_fkey
            FOREIGN KEY (player_user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'player_game_stats_event_id_fkey'
    ) THEN
        ALTER TABLE public.player_game_stats
            ADD CONSTRAINT player_game_stats_event_id_fkey
            FOREIGN KEY (event_id) REFERENCES public.event(event_id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'player_game_stats_recorded_by_fkey'
    ) THEN
        ALTER TABLE public.player_game_stats
            ADD CONSTRAINT player_game_stats_recorded_by_fkey
            FOREIGN KEY (recorded_by) REFERENCES public.users(user_id) ON DELETE RESTRICT;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.player_game_stats
        WHERE team_id IS NULL OR player_user_id IS NULL OR recorded_by IS NULL
    ) THEN
        ALTER TABLE public.player_game_stats ALTER COLUMN team_id SET NOT NULL;
        ALTER TABLE public.player_game_stats ALTER COLUMN player_user_id SET NOT NULL;
        ALTER TABLE public.player_game_stats ALTER COLUMN recorded_by SET NOT NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_player_game_stats_team_match
ON public.player_game_stats (team_id, match_date DESC);

CREATE INDEX IF NOT EXISTS idx_player_game_stats_player_match
ON public.player_game_stats (player_user_id, match_date DESC);
