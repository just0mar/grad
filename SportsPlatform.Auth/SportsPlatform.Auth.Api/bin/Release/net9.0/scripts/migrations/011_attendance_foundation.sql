-- ============================================================
-- 011: Attendance foundation
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'attendance_status'
          AND n.nspname = 'public'
    ) THEN
        CREATE TYPE public.attendance_status AS ENUM ('Present', 'Absent', 'Late', 'Injured');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.attendance (
    attendance_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid NOT NULL REFERENCES public.event(event_id) ON DELETE CASCADE,
    instance_date date NULL,
    player_id uuid NOT NULL REFERENCES public.player_profile(player_id) ON DELETE CASCADE,
    recorded_by_user_id uuid NULL,
    status public.attendance_status NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    notes text NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.attendance
    ADD COLUMN IF NOT EXISTS instance_date date NULL,
    ADD COLUMN IF NOT EXISTS recorded_by_user_id uuid NULL,
    ADD COLUMN IF NOT EXISTS recorded_at timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS notes text NULL;

UPDATE public.attendance a
SET instance_date = COALESCE(a.instance_date, e.start_at::date)
FROM public.event e
WHERE a.event_id = e.event_id
  AND a.instance_date IS NULL;

ALTER TABLE public.attendance
    ALTER COLUMN instance_date SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'attendance_recorded_by_user_id_fkey'
    ) THEN
        ALTER TABLE public.attendance
            ADD CONSTRAINT attendance_recorded_by_user_id_fkey
            FOREIGN KEY (recorded_by_user_id) REFERENCES public.users(user_id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'uq_attendance_event_instance_player'
    ) THEN
        ALTER TABLE public.attendance
            ADD CONSTRAINT uq_attendance_event_instance_player
            UNIQUE (event_id, instance_date, player_id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_attendance_event_instance
ON public.attendance (event_id, instance_date);

CREATE INDEX IF NOT EXISTS idx_attendance_player
ON public.attendance (player_id);
