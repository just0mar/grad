-- ============================================================
-- 007: Drop legacy approval/role schema after v8 cutover
-- ============================================================

DROP TABLE IF EXISTS public.user_role CASCADE;
DROP TABLE IF EXISTS public.user_approval_request CASCADE;
DROP TABLE IF EXISTS public.team_manager CASCADE;
DROP TABLE IF EXISTS public.role CASCADE;

ALTER TABLE IF EXISTS public.team
    DROP COLUMN IF EXISTS manager_user_id;

DROP TYPE IF EXISTS public.approval_request_status CASCADE;
DROP TYPE IF EXISTS public.user_role_status CASCADE;
