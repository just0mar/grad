-- ============================================================
-- 003: RLS helpers + policy rebuild for pipe-delimited roles
-- Aligns RLS with current middleware session variables and
-- multi-manager team ownership via team_manager.
-- ============================================================

CREATE OR REPLACE FUNCTION public.current_app_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(current_setting('app.user_id', true), '')::uuid
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT coalesce(current_setting('app.user_roles', true), '') LIKE '%|Admin|%'
$$;

CREATE OR REPLACE FUNCTION public.is_current_user_team_manager(p_team_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.team_manager tm
        WHERE tm.team_id = p_team_id
          AND tm.user_id = public.current_app_user_id()
    )
$$;

CREATE OR REPLACE FUNCTION public.is_current_user_team_member(p_team_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.user_role ur
        WHERE ur.team_id = p_team_id
          AND ur.user_id = public.current_app_user_id()
          AND ur.status = 'Approved'
    )
$$;

-- Keep the legacy helper in place during transitional runs.
-- Older policies may still depend on it at the moment this script executes.
-- Later v8 migrations replace the active policy set entirely.

ALTER TABLE IF EXISTS public.team ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS team_admin_all ON public.team;
CREATE POLICY team_admin_all
ON public.team
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS team_manager_select ON public.team;
CREATE POLICY team_manager_select
ON public.team
FOR SELECT
USING (public.is_current_user_team_manager(team_id));

DROP POLICY IF EXISTS team_manager_insert ON public.team;
CREATE POLICY team_manager_insert
ON public.team
FOR INSERT
WITH CHECK (
    public.is_admin()
    OR public.is_current_user_team_manager(team_id)
);

DROP POLICY IF EXISTS team_manager_update ON public.team;
CREATE POLICY team_manager_update
ON public.team
FOR UPDATE
USING (public.is_current_user_team_manager(team_id))
WITH CHECK (public.is_current_user_team_manager(team_id));

DROP POLICY IF EXISTS team_manager_delete ON public.team;
CREATE POLICY team_manager_delete
ON public.team
FOR DELETE
USING (public.is_current_user_team_manager(team_id));

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name = 'coaching_plan'
    ) THEN
        EXECUTE 'ALTER TABLE public.coaching_plan ENABLE ROW LEVEL SECURITY';

        EXECUTE 'DROP POLICY IF EXISTS coaching_plan_admin_all ON public.coaching_plan';
        EXECUTE '
            CREATE POLICY coaching_plan_admin_all
            ON public.coaching_plan
            FOR ALL
            USING (public.is_admin())
            WITH CHECK (public.is_admin())
        ';

        EXECUTE 'DROP POLICY IF EXISTS coaching_plan_manager_select ON public.coaching_plan';
        EXECUTE '
            CREATE POLICY coaching_plan_manager_select
            ON public.coaching_plan
            FOR SELECT
            USING (public.is_current_user_team_manager(team_id))
        ';

        EXECUTE 'DROP POLICY IF EXISTS coaching_plan_manager_update ON public.coaching_plan';
        EXECUTE '
            CREATE POLICY coaching_plan_manager_update
            ON public.coaching_plan
            FOR UPDATE
            USING (public.is_current_user_team_manager(team_id))
            WITH CHECK (public.is_current_user_team_manager(team_id))
        ';

        EXECUTE 'DROP POLICY IF EXISTS coaching_plan_manager_delete ON public.coaching_plan';
        EXECUTE '
            CREATE POLICY coaching_plan_manager_delete
            ON public.coaching_plan
            FOR DELETE
            USING (public.is_current_user_team_manager(team_id))
        ';

        EXECUTE 'DROP POLICY IF EXISTS coaching_plan_coach_select ON public.coaching_plan';
        EXECUTE '
            CREATE POLICY coaching_plan_coach_select
            ON public.coaching_plan
            FOR SELECT
            USING (
                EXISTS (
                    SELECT 1
                    FROM public.team_staff ts
                    WHERE ts.staff_id = coaching_plan.creator_staff_id
                      AND ts.user_id = public.current_app_user_id()
                )
            )
        ';

        EXECUTE 'DROP POLICY IF EXISTS coaching_plan_coach_insert ON public.coaching_plan';
        EXECUTE '
            CREATE POLICY coaching_plan_coach_insert
            ON public.coaching_plan
            FOR INSERT
            WITH CHECK (
                EXISTS (
                    SELECT 1
                    FROM public.team_staff ts
                    WHERE ts.staff_id = coaching_plan.creator_staff_id
                      AND ts.user_id = public.current_app_user_id()
                )
            )
        ';

        EXECUTE 'DROP POLICY IF EXISTS coaching_plan_coach_update ON public.coaching_plan';
        EXECUTE '
            CREATE POLICY coaching_plan_coach_update
            ON public.coaching_plan
            FOR UPDATE
            USING (
                EXISTS (
                    SELECT 1
                    FROM public.team_staff ts
                    WHERE ts.staff_id = coaching_plan.creator_staff_id
                      AND ts.user_id = public.current_app_user_id()
                )
            )
            WITH CHECK (
                EXISTS (
                    SELECT 1
                    FROM public.team_staff ts
                    WHERE ts.staff_id = coaching_plan.creator_staff_id
                      AND ts.user_id = public.current_app_user_id()
                )
            )
        ';

        EXECUTE 'DROP POLICY IF EXISTS coaching_plan_coach_delete ON public.coaching_plan';
        EXECUTE '
            CREATE POLICY coaching_plan_coach_delete
            ON public.coaching_plan
            FOR DELETE
            USING (
                EXISTS (
                    SELECT 1
                    FROM public.team_staff ts
                    WHERE ts.staff_id = coaching_plan.creator_staff_id
                      AND ts.user_id = public.current_app_user_id()
                )
            )
        ';
    END IF;
END $$;
