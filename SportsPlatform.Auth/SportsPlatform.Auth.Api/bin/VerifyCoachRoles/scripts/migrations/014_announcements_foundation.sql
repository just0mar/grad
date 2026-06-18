-- ============================================================
-- 014: Announcements foundation
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'announcement_priority'
          AND n.nspname = 'public'
    ) THEN
        CREATE TYPE public.announcement_priority AS ENUM ('Normal', 'Important', 'Urgent');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.announcement (
    announcement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id uuid NOT NULL REFERENCES public.team(team_id) ON DELETE CASCADE,
    created_by uuid NOT NULL REFERENCES public.users(user_id) ON DELETE RESTRICT,
    title varchar(200) NOT NULL,
    content text NOT NULL,
    priority public.announcement_priority NOT NULL DEFAULT 'Normal',
    deleted_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'announcement'
          AND column_name = 'creator_user_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'announcement'
          AND column_name = 'created_by'
    ) THEN
        ALTER TABLE public.announcement RENAME COLUMN creator_user_id TO created_by;
    END IF;
END $$;

ALTER TABLE public.announcement
    ADD COLUMN IF NOT EXISTS created_by uuid NULL,
    ADD COLUMN IF NOT EXISTS priority public.announcement_priority NOT NULL DEFAULT 'Normal',
    ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL,
    ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'announcement'
          AND column_name = 'creator_user_id'
    ) THEN
        UPDATE public.announcement
        SET created_by = creator_user_id
        WHERE created_by IS NULL;

        ALTER TABLE public.announcement ALTER COLUMN creator_user_id DROP NOT NULL;
    END IF;

    UPDATE public.announcement
    SET priority = 'Normal'
    WHERE priority IS NULL;

    IF NOT EXISTS (
        SELECT 1
        FROM public.announcement
        WHERE created_by IS NULL
    ) THEN
        ALTER TABLE public.announcement ALTER COLUMN created_by SET NOT NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'announcement_created_by_fkey'
    ) THEN
        ALTER TABLE public.announcement
            ADD CONSTRAINT announcement_created_by_fkey
            FOREIGN KEY (created_by) REFERENCES public.users(user_id) ON DELETE RESTRICT;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_announcement_team_created
ON public.announcement (team_id, created_at DESC)
WHERE deleted_at IS NULL;
