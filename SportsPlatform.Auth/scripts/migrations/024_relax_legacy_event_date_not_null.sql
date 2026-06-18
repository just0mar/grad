-- ============================================================
-- 024: Relax legacy event.event_date after start_at migration
-- ============================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'event'
          AND column_name = 'event_date'
          AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.event
            ALTER COLUMN event_date DROP NOT NULL;
    END IF;
END $$;
