-- ============================================================
-- 032: Add Test event type
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_enum e
        JOIN pg_type t ON t.oid = e.enumtypid
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE n.nspname = 'public'
          AND t.typname = 'event_type'
          AND e.enumlabel = 'Test'
    ) THEN
        ALTER TYPE public.event_type ADD VALUE 'Test';
    END IF;
END $$;
