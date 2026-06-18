-- ============================================================
-- REFRESH TOKEN TABLE
-- Run this after the main schema script.
--
-- This script supports three cases:
-- 1) No refresh_token table exists yet -> create the current schema
-- 2) A near-current table exists -> repair missing columns/indexes
-- 3) A legacy table exists (token_id/token_hash/auth_provider_id/etc.) -> back it up and recreate
-- ============================================================

DO $$
BEGIN
    IF to_regclass('public.refresh_token') IS NULL THEN
        CREATE TABLE public.refresh_token (
            id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id    UUID        NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
            token      TEXT        NOT NULL UNIQUE,
            expires_at TIMESTAMPTZ NOT NULL,
            revoked_at TIMESTAMPTZ,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
    END IF;
END $$;

-- Backward compatibility: older schema used refresh_token_id.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'refresh_token'
          AND column_name = 'refresh_token_id'
    )
    AND NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'refresh_token'
          AND column_name = 'id'
    ) THEN
        ALTER TABLE public.refresh_token RENAME COLUMN refresh_token_id TO id;
    END IF;
END $$;

-- If the table is from the older token store design, back it up and recreate
-- the current schema instead of trying to mutate it in place.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'refresh_token'
          AND column_name = 'token_id'
    ) OR EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'refresh_token'
          AND column_name = 'token_hash'
    ) OR EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'refresh_token'
          AND column_name = 'auth_provider_id'
    ) THEN
        IF to_regclass('public.refresh_token_legacy_backup') IS NOT NULL THEN
            DROP TABLE public.refresh_token_legacy_backup;
        END IF;

        ALTER TABLE public.refresh_token RENAME TO refresh_token_legacy_backup;

        CREATE TABLE public.refresh_token (
            id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id    UUID        NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
            token      TEXT        NOT NULL UNIQUE,
            expires_at TIMESTAMPTZ NOT NULL,
            revoked_at TIMESTAMPTZ,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
    END IF;
END $$;

-- Repair a near-current table that exists but is missing a few columns.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'refresh_token'
          AND column_name = 'id'
    ) THEN
        ALTER TABLE public.refresh_token ADD COLUMN id UUID;
        UPDATE public.refresh_token SET id = gen_random_uuid() WHERE id IS NULL;
        ALTER TABLE public.refresh_token ALTER COLUMN id SET NOT NULL;
        ALTER TABLE public.refresh_token ADD PRIMARY KEY (id);
        ALTER TABLE public.refresh_token ALTER COLUMN id SET DEFAULT gen_random_uuid();
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'refresh_token'
          AND column_name = 'token'
    ) THEN
        ALTER TABLE public.refresh_token ADD COLUMN token TEXT;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'refresh_token'
          AND column_name = 'expires_at'
    ) THEN
        ALTER TABLE public.refresh_token ADD COLUMN expires_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'refresh_token'
          AND column_name = 'created_at'
    ) THEN
        ALTER TABLE public.refresh_token ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'refresh_token'
          AND column_name = 'revoked_at'
    ) THEN
        ALTER TABLE public.refresh_token ADD COLUMN revoked_at TIMESTAMPTZ;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_refresh_token_user ON public.refresh_token (user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_token_token ON public.refresh_token (token);
