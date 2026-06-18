-- ============================================================
-- 018: Team-scoped seasons
-- ============================================================

ALTER TABLE public.season
    ADD COLUMN IF NOT EXISTS team_id uuid NULL,
    ADD COLUMN IF NOT EXISTS created_by uuid NULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'season_label_key'
          AND conrelid = 'public.season'::regclass
    ) THEN
        ALTER TABLE public.season DROP CONSTRAINT season_label_key;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'season_team_id_fkey'
          AND conrelid = 'public.season'::regclass
    ) THEN
        ALTER TABLE public.season
            ADD CONSTRAINT season_team_id_fkey
            FOREIGN KEY (team_id) REFERENCES public.team(team_id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'season_created_by_fkey'
          AND conrelid = 'public.season'::regclass
    ) THEN
        ALTER TABLE public.season
            ADD CONSTRAINT season_created_by_fkey
            FOREIGN KEY (created_by) REFERENCES public.users(user_id) ON DELETE SET NULL;
    END IF;
END $$;

DROP INDEX IF EXISTS public.idx_season_one_current;
DROP INDEX IF EXISTS public.ix_season_label;

WITH ranked_current AS (
    SELECT
        season_id,
        ROW_NUMBER() OVER (
            PARTITION BY team_id
            ORDER BY updated_at DESC, created_at DESC, season_id
        ) AS rn
    FROM public.season
    WHERE team_id IS NOT NULL
      AND is_current = true
)
UPDATE public.season s
SET is_current = false,
    updated_at = now()
FROM ranked_current r
WHERE s.season_id = r.season_id
  AND r.rn > 1;

WITH duplicate_labels AS (
    SELECT
        season_id,
        ROW_NUMBER() OVER (
            PARTITION BY team_id, label
            ORDER BY created_at, season_id
        ) AS rn
    FROM public.season
    WHERE team_id IS NOT NULL
)
UPDATE public.season s
SET label = CONCAT(s.label, ' ', LEFT(s.season_id::text, 8)),
    updated_at = now()
FROM duplicate_labels d
WHERE s.season_id = d.season_id
  AND d.rn > 1;

DO $$
DECLARE
    start_year integer;
    default_label text;
    default_start date;
    default_end date;
BEGIN
    start_year := CASE
        WHEN EXTRACT(MONTH FROM CURRENT_DATE)::integer >= 7
            THEN EXTRACT(YEAR FROM CURRENT_DATE)::integer
        ELSE EXTRACT(YEAR FROM CURRENT_DATE)::integer - 1
    END;

    default_label := start_year::text || '/' || (start_year + 1)::text;
    default_start := make_date(start_year, 7, 1);
    default_end := make_date(start_year + 1, 6, 30);

    INSERT INTO public.season (
        season_id,
        team_id,
        created_by,
        label,
        start_date,
        end_date,
        is_current,
        created_at,
        updated_at
    )
    SELECT
        gen_random_uuid(),
        t.team_id,
        COALESCE(t.created_by, c.created_by),
        default_label,
        default_start,
        default_end,
        true,
        now(),
        now()
    FROM public.team t
    LEFT JOIN public.club c ON c.club_id = t.club_id
    WHERE t.deleted_at IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM public.season s
          WHERE s.team_id = t.team_id
            AND s.is_current = true
      );
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_season_team_one_current
ON public.season (team_id)
WHERE team_id IS NOT NULL
  AND is_current = true;

CREATE UNIQUE INDEX IF NOT EXISTS idx_season_global_one_current
ON public.season (is_current)
WHERE team_id IS NULL
  AND is_current = true;

CREATE UNIQUE INDEX IF NOT EXISTS idx_season_team_label
ON public.season (team_id, label)
WHERE team_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_season_global_label
ON public.season (label)
WHERE team_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_season_team_start_date
ON public.season (team_id, start_date DESC)
WHERE team_id IS NOT NULL;
