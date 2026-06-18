-- ============================================================
-- 010: Season + event scheduling foundation
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'event_type'
          AND n.nspname = 'public'
    ) THEN
        CREATE TYPE public.event_type AS ENUM ('Match', 'Training', 'Meeting', 'Test');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.season (
    season_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    label varchar(50) NOT NULL UNIQUE,
    start_date date NOT NULL,
    end_date date NOT NULL,
    is_current boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_season_dates CHECK (end_date > start_date)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_season_one_current
ON public.season (is_current)
WHERE is_current = true;

CREATE TABLE IF NOT EXISTS public.event (
    event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id uuid NOT NULL REFERENCES public.team(team_id) ON DELETE CASCADE,
    season_id uuid NOT NULL REFERENCES public.season(season_id) ON DELETE RESTRICT,
    created_by uuid NULL,
    title varchar(200) NULL,
    description text NULL,
    location varchar(200) NULL,
    start_at timestamptz NULL,
    end_at timestamptz NULL,
    event_type public.event_type NOT NULL,
    timezone varchar(100) NOT NULL DEFAULT 'UTC',
    recurrence_rule text NULL,
    recurrence_end_date timestamptz NULL,
    deleted_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.event
    ADD COLUMN IF NOT EXISTS created_by uuid NULL,
    ADD COLUMN IF NOT EXISTS title varchar(200) NULL,
    ADD COLUMN IF NOT EXISTS description text NULL,
    ADD COLUMN IF NOT EXISTS location varchar(200) NULL,
    ADD COLUMN IF NOT EXISTS start_at timestamptz NULL,
    ADD COLUMN IF NOT EXISTS end_at timestamptz NULL,
    ADD COLUMN IF NOT EXISTS timezone varchar(100) NOT NULL DEFAULT 'UTC',
    ADD COLUMN IF NOT EXISTS recurrence_rule text NULL,
    ADD COLUMN IF NOT EXISTS recurrence_end_date timestamptz NULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'event'
          AND column_name = 'event_date'
    ) THEN
        UPDATE public.event
        SET start_at = event_date
        WHERE start_at IS NULL;
    END IF;
END $$;

UPDATE public.event e
SET title = CONCAT(COALESCE(e.event_type::text, 'Scheduled'), ' Event')
WHERE e.title IS NULL;

UPDATE public.event e
SET created_by = COALESCE(t.created_by, c.created_by)
FROM public.team t
LEFT JOIN public.club c ON c.club_id = t.club_id
WHERE e.team_id = t.team_id
  AND e.created_by IS NULL;

ALTER TABLE public.event
    ALTER COLUMN title SET NOT NULL,
    ALTER COLUMN start_at SET NOT NULL,
    ALTER COLUMN timezone SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'event_created_by_fkey'
    ) THEN
        ALTER TABLE public.event
            ADD CONSTRAINT event_created_by_fkey
            FOREIGN KEY (created_by) REFERENCES public.users(user_id) ON DELETE RESTRICT;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_event_end_after_start'
    ) THEN
        ALTER TABLE public.event
            ADD CONSTRAINT chk_event_end_after_start
            CHECK (end_at IS NULL OR end_at > start_at);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_event_team_start_at ON public.event (team_id, start_at);
CREATE INDEX IF NOT EXISTS idx_event_season_id ON public.event (season_id);

CREATE TABLE IF NOT EXISTS public.event_exception (
    event_exception_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES public.event(event_id) ON DELETE CASCADE,
    original_date date NOT NULL,
    new_start_at timestamptz NULL,
    new_end_at timestamptz NULL,
    is_cancelled boolean NOT NULL DEFAULT false,
    notes text NULL,
    created_by uuid NOT NULL REFERENCES public.users(user_id) ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_event_exception_original_date UNIQUE (event_id, original_date),
    CONSTRAINT chk_event_exception_reschedule_window CHECK (new_end_at IS NULL OR new_start_at IS NULL OR new_end_at > new_start_at)
);

CREATE INDEX IF NOT EXISTS idx_event_exception_event_id ON public.event_exception (event_id);
