-- ============================================================
-- 034: Biometric snapshots for height/weight history
-- ============================================================

ALTER TABLE public.fitness_record
    ADD COLUMN IF NOT EXISTS height numeric(5,2) NULL,
    ADD COLUMN IF NOT EXISTS weight numeric(5,2) NULL;
