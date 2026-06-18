-- 049: Add recipient-denied invitation status.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_enum e
        JOIN pg_type t ON t.oid = e.enumtypid
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE n.nspname = 'public'
          AND t.typname = 'invitation_status'
          AND e.enumlabel = 'Denied'
    ) THEN
        ALTER TYPE public.invitation_status ADD VALUE 'Denied';
    END IF;
END $$;
