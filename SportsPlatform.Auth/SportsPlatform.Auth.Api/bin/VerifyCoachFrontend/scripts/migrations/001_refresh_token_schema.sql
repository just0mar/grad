-- ============================================================
-- 001: Ensure refresh_token table schema is correct
-- Extracted from Program.cs startup SQL block
-- ============================================================

CREATE TABLE IF NOT EXISTS public.refresh_token (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Rename legacy column if present
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
