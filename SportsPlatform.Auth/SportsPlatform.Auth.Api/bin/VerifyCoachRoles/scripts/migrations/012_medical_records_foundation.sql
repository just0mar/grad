-- ============================================================
-- 012: Medical records foundation
-- ============================================================

CREATE TABLE IF NOT EXISTS public.medical_record (
    record_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id uuid NULL,
    player_id uuid NOT NULL REFERENCES public.player_profile(player_id) ON DELETE CASCADE,
    doctor_user_id uuid NULL,
    record_date timestamptz NOT NULL DEFAULT now(),
    injury_type varchar(200) NULL,
    diagnosis text NULL,
    expected_return_date date NULL,
    is_cleared boolean NOT NULL DEFAULT false,
    created_by uuid NULL,
    updated_by uuid NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.medical_record
    ADD COLUMN IF NOT EXISTS team_id uuid NULL,
    ADD COLUMN IF NOT EXISTS doctor_user_id uuid NULL,
    ADD COLUMN IF NOT EXISTS is_cleared boolean NOT NULL DEFAULT false;

UPDATE public.medical_record mr
SET team_id = pt.team_id
FROM public.player_team pt
WHERE mr.player_id = pt.player_id
  AND pt.is_current = true
  AND mr.team_id IS NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'medical_record_team_id_fkey'
    ) THEN
        ALTER TABLE public.medical_record
            ADD CONSTRAINT medical_record_team_id_fkey
            FOREIGN KEY (team_id) REFERENCES public.team(team_id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'medical_record_doctor_user_id_fkey'
    ) THEN
        ALTER TABLE public.medical_record
            ADD CONSTRAINT medical_record_doctor_user_id_fkey
            FOREIGN KEY (doctor_user_id) REFERENCES public.users(user_id) ON DELETE SET NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_medical_record_team_id ON public.medical_record (team_id);
CREATE INDEX IF NOT EXISTS idx_medical_record_player_id ON public.medical_record (player_id);
