-- ============================================================
-- 013: Fitness records foundation
-- ============================================================

CREATE TABLE IF NOT EXISTS public.fitness_record (
    fitness_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id uuid NULL,
    player_id uuid NOT NULL REFERENCES public.player_profile(player_id) ON DELETE CASCADE,
    fitness_user_id uuid NULL,
    test_date timestamptz NOT NULL DEFAULT now(),
    bmi numeric(5,2) NULL,
    body_fat_pct numeric(5,2) NULL,
    speed_test_result numeric(6,2) NULL,
    endurance_score numeric(6,2) NULL,
    created_by uuid NULL,
    updated_by uuid NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.fitness_record
    ADD COLUMN IF NOT EXISTS team_id uuid NULL,
    ADD COLUMN IF NOT EXISTS fitness_user_id uuid NULL,
    ADD COLUMN IF NOT EXISTS created_by uuid NULL,
    ADD COLUMN IF NOT EXISTS updated_by uuid NULL;

UPDATE public.fitness_record fr
SET team_id = pt.team_id
FROM public.player_team pt
WHERE fr.player_id = pt.player_id
  AND pt.is_current = true
  AND fr.team_id IS NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fitness_record_team_id_fkey'
    ) THEN
        ALTER TABLE public.fitness_record
            ADD CONSTRAINT fitness_record_team_id_fkey
            FOREIGN KEY (team_id) REFERENCES public.team(team_id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fitness_record_fitness_user_id_fkey'
    ) THEN
        ALTER TABLE public.fitness_record
            ADD CONSTRAINT fitness_record_fitness_user_id_fkey
            FOREIGN KEY (fitness_user_id) REFERENCES public.users(user_id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fitness_record_created_by_fkey'
    ) THEN
        ALTER TABLE public.fitness_record
            ADD CONSTRAINT fitness_record_created_by_fkey
            FOREIGN KEY (created_by) REFERENCES public.users(user_id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fitness_record_updated_by_fkey'
    ) THEN
        ALTER TABLE public.fitness_record
            ADD CONSTRAINT fitness_record_updated_by_fkey
            FOREIGN KEY (updated_by) REFERENCES public.users(user_id) ON DELETE SET NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_fitness_record_team_id ON public.fitness_record (team_id);
CREATE INDEX IF NOT EXISTS idx_fitness_record_player_id ON public.fitness_record (player_id);
