-- ============================================================
-- 015: Coaching plans foundation
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'plan_visibility'
          AND n.nspname = 'public'
    ) THEN
        CREATE TYPE public.plan_visibility AS ENUM ('Draft', 'TeamVisible', 'PlayerAssigned');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.coaching_plan (
    plan_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id uuid NOT NULL REFERENCES public.team(team_id) ON DELETE CASCADE,
    created_by uuid NOT NULL REFERENCES public.users(user_id) ON DELETE RESTRICT,
    title varchar(200) NOT NULL,
    description text NULL,
    content text NOT NULL,
    visibility public.plan_visibility NOT NULL DEFAULT 'Draft',
    deleted_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.coaching_plan
    ADD COLUMN IF NOT EXISTS created_by uuid NULL,
    ADD COLUMN IF NOT EXISTS description text NULL,
    ADD COLUMN IF NOT EXISTS content text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS visibility public.plan_visibility NOT NULL DEFAULT 'Draft',
    ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL,
    ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'coaching_plan'
          AND column_name = 'creator_staff_id'
    ) THEN
        UPDATE public.coaching_plan cp
        SET created_by = ts.user_id
        FROM public.team_staff ts
        WHERE cp.creator_staff_id = ts.staff_id
          AND cp.created_by IS NULL;

        ALTER TABLE public.coaching_plan ALTER COLUMN creator_staff_id DROP NOT NULL;
    END IF;

    UPDATE public.coaching_plan
    SET visibility = 'Draft'
    WHERE visibility IS NULL;

    IF NOT EXISTS (
        SELECT 1
        FROM public.coaching_plan
        WHERE created_by IS NULL
    ) THEN
        ALTER TABLE public.coaching_plan ALTER COLUMN created_by SET NOT NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'coaching_plan_created_by_fkey'
    ) THEN
        ALTER TABLE public.coaching_plan
            ADD CONSTRAINT coaching_plan_created_by_fkey
            FOREIGN KEY (created_by) REFERENCES public.users(user_id) ON DELETE RESTRICT;
    END IF;
END $$;

DROP POLICY IF EXISTS coaching_plan_admin_all ON public.coaching_plan;
DROP POLICY IF EXISTS coaching_plan_manager_select ON public.coaching_plan;
DROP POLICY IF EXISTS coaching_plan_manager_update ON public.coaching_plan;
DROP POLICY IF EXISTS coaching_plan_manager_delete ON public.coaching_plan;
DROP POLICY IF EXISTS coaching_plan_coach_select ON public.coaching_plan;
DROP POLICY IF EXISTS coaching_plan_coach_insert ON public.coaching_plan;
DROP POLICY IF EXISTS coaching_plan_coach_update ON public.coaching_plan;
DROP POLICY IF EXISTS coaching_plan_coach_delete ON public.coaching_plan;
ALTER TABLE public.coaching_plan DISABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_coaching_plan_team_updated
ON public.coaching_plan (team_id, updated_at DESC)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_coaching_plan_creator
ON public.coaching_plan (created_by)
WHERE deleted_at IS NULL;
