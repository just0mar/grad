-- ============================================================
-- 005: Transitional role enum expansion only
-- PostgreSQL requires enum additions to be committed before
-- those new values can be referenced by constraints/indexes.
-- Follow-up migration 005a applies the dependent constraints.
-- ============================================================

-- Step 1: Expand existing role enum with the new redesign values.
-- Keep legacy values for now so the old code path still works during cutover.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_enum e
        JOIN pg_type t ON t.oid = e.enumtypid
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'role_name_type'
          AND n.nspname = 'public'
          AND e.enumlabel = 'ClubManager'
    ) THEN
        ALTER TYPE public.role_name_type ADD VALUE 'ClubManager';
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_enum e
        JOIN pg_type t ON t.oid = e.enumtypid
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'role_name_type'
          AND n.nspname = 'public'
          AND e.enumlabel = 'TeamManager'
    ) THEN
        ALTER TYPE public.role_name_type ADD VALUE 'TeamManager';
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_enum e
        JOIN pg_type t ON t.oid = e.enumtypid
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'role_name_type'
          AND n.nspname = 'public'
          AND e.enumlabel = 'Coach'
    ) THEN
        ALTER TYPE public.role_name_type ADD VALUE 'Coach';
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_enum e
        JOIN pg_type t ON t.oid = e.enumtypid
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'role_name_type'
          AND n.nspname = 'public'
          AND e.enumlabel = 'TeamAnalyst'
    ) THEN
        ALTER TYPE public.role_name_type ADD VALUE 'TeamAnalyst';
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_enum e
        JOIN pg_type t ON t.oid = e.enumtypid
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'role_name_type'
          AND n.nspname = 'public'
          AND e.enumlabel = 'TeamDoctor'
    ) THEN
        ALTER TYPE public.role_name_type ADD VALUE 'TeamDoctor';
    END IF;
END $$;
