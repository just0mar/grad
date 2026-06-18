-- ============================================================
-- AUTHORITY REDESIGN MIGRATION
-- Run this ONCE against the SportsPlatform database
-- ============================================================

BEGIN;

-- ── 1. Update role_name_type enum ──────────────────────────
-- Add new values
ALTER TYPE public.role_name_type ADD VALUE IF NOT EXISTS 'FitnessCoach';
ALTER TYPE public.role_name_type ADD VALUE IF NOT EXISTS 'BasketballCoach';

COMMIT;

-- NOTE: Cannot remove enum values in PostgreSQL without recreating the type.
-- 'Coach' remains in the enum but we remove it from the role table below.
-- If no data references 'Coach', it's harmless to leave it in the enum type.

BEGIN;

-- ── 2. Update staff_role_type enum ─────────────────────────
-- Add 'Fitness Coach' for the fitness coach staff role
ALTER TYPE public.staff_role_type ADD VALUE IF NOT EXISTS 'Fitness Coach';

COMMIT;

BEGIN;

-- ── 3. Insert new role rows ────────────────────────────────
INSERT INTO public.role (role_id, role_name, created_at, updated_at)
SELECT gen_random_uuid(), 'FitnessCoach'::role_name_type, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.role WHERE role_name = 'FitnessCoach');

INSERT INTO public.role (role_id, role_name, created_at, updated_at)
SELECT gen_random_uuid(), 'BasketballCoach'::role_name_type, NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM public.role WHERE role_name = 'BasketballCoach');

-- Delete old Coach role (only if no user_role references it)
DELETE FROM public.role
WHERE role_name = 'Coach'
  AND NOT EXISTS (
    SELECT 1 FROM public.user_role ur WHERE ur.role_id = role.role_id
  );

-- ── 4. Make عمر an Admin ───────────────────────────────────
DO $$
DECLARE
    v_user_id UUID;
    v_admin_role_id UUID;
    v_manager_role_id UUID;
BEGIN
    -- Find عمر
    SELECT user_id INTO v_user_id
    FROM public.users
    WHERE email = 'omar.elsaid253@gmail.com';

    IF v_user_id IS NULL THEN
        RAISE NOTICE 'User omar.elsaid253@gmail.com not found. Skipping.';
        RETURN;
    END IF;

    -- Get role IDs
    SELECT role_id INTO v_admin_role_id
    FROM public.role WHERE role_name = 'Admin';

    SELECT role_id INTO v_manager_role_id
    FROM public.role WHERE role_name = 'Manager';

    -- Remove existing Manager role
    DELETE FROM public.user_role
    WHERE user_id = v_user_id AND role_id = v_manager_role_id;

    -- Assign Admin role (if not already)
    IF NOT EXISTS (
        SELECT 1 FROM public.user_role
        WHERE user_id = v_user_id AND role_id = v_admin_role_id
    ) THEN
        INSERT INTO public.user_role
            (user_role_id, user_id, role_id, team_id, status, assigned_by, assigned_at, created_at, updated_at)
        VALUES
            (gen_random_uuid(), v_user_id, v_admin_role_id, NULL,
             'Approved'::user_role_status, v_user_id, NOW(), NOW(), NOW());
    END IF;

    RAISE NOTICE 'عمر is now Admin.';
END $$;

-- ── 5. Update check_staff_has_role() trigger ───────────────
CREATE OR REPLACE FUNCTION public.check_staff_has_role() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    required_role role_name_type;
BEGIN
    required_role := CASE NEW.staff_role
        WHEN 'Head Coach'     THEN 'BasketballCoach'
        WHEN 'Fitness Coach'  THEN 'FitnessCoach'
        WHEN 'Medic'          THEN 'Medic'
        WHEN 'Analyst'        THEN 'Analyst'
    END;
    IF NOT EXISTS (
        SELECT 1 FROM user_role ur
        JOIN role r ON r.role_id = ur.role_id
        WHERE ur.user_id  = NEW.user_id
          AND ur.team_id  = NEW.team_id
          AND r.role_name = required_role
          AND ur.status   = 'Approved'
    ) THEN
        RAISE EXCEPTION 'User % needs an approved % role on team % before becoming team_staff',
            NEW.user_id, required_role, NEW.team_id;
    END IF;
    RETURN NEW;
END;
$$;

-- ── 6. Verify ──────────────────────────────────────────────
SELECT u.email, r.role_name, ur.status
FROM public.user_role ur
JOIN public.users u ON u.user_id = ur.user_id
JOIN public.role r ON r.role_id = ur.role_id
ORDER BY u.email;

SELECT unnest(enum_range(NULL::role_name_type)) AS role_values;
SELECT role_id, role_name FROM public.role ORDER BY role_name;

COMMIT;
