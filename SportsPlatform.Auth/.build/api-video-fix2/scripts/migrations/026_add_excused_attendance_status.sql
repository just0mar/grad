-- ============================================================
-- 026: Add Excused attendance status
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_enum e ON e.enumtypid = t.oid
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE n.nspname = 'public'
          AND t.typname = 'attendance_status'
          AND e.enumlabel = 'Excused'
    ) THEN
        ALTER TYPE public.attendance_status ADD VALUE 'Excused';
    END IF;
END $$;
