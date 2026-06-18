-- ============================================================
-- 006: RLS helpers + policies for v8 membership model
-- Requires the app to set:
--   app.user_id
--   app.is_admin
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
    SELECT current_setting('app.is_admin', true) = 'true'
$$;

CREATE OR REPLACE FUNCTION public.is_club_manager(p_club_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.club c
        WHERE c.club_id = p_club_id
          AND c.created_by = public.current_app_user_id()
          AND c.deleted_at IS NULL
    )
$$;

CREATE OR REPLACE FUNCTION public.is_active_club_member(p_club_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.club_membership cm
        WHERE cm.club_id = p_club_id
          AND cm.user_id = public.current_app_user_id()
          AND cm.status = 'Active'
    )
$$;

CREATE OR REPLACE FUNCTION public.is_active_team_member(p_team_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.team_membership tm
        WHERE tm.team_id = p_team_id
          AND tm.user_id = public.current_app_user_id()
          AND tm.status = 'Active'
    )
$$;

CREATE OR REPLACE FUNCTION public.is_team_manager(p_team_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.team_membership tm
        WHERE tm.team_id = p_team_id
          AND tm.user_id = public.current_app_user_id()
          AND tm.role = 'TeamManager'
          AND tm.status = 'Active'
    )
$$;

ALTER TABLE IF EXISTS public.club ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.club_membership ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.team ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.team_membership ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.invitation ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS club_admin_all ON public.club;
CREATE POLICY club_admin_all
ON public.club
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS club_visible_to_members ON public.club;
CREATE POLICY club_visible_to_members
ON public.club
FOR SELECT
USING (
    public.is_club_manager(club_id)
    OR public.is_active_club_member(club_id)
    OR EXISTS (
        SELECT 1
        FROM public.team t
        JOIN public.team_membership tm ON tm.team_id = t.team_id
        WHERE t.club_id = club.club_id
          AND t.deleted_at IS NULL
          AND tm.user_id = public.current_app_user_id()
          AND tm.status = 'Active'
    )
);

DROP POLICY IF EXISTS club_manager_update ON public.club;
CREATE POLICY club_manager_update
ON public.club
FOR UPDATE
USING (public.is_club_manager(club_id))
WITH CHECK (public.is_club_manager(club_id));

DROP POLICY IF EXISTS club_membership_admin_all ON public.club_membership;
CREATE POLICY club_membership_admin_all
ON public.club_membership
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS club_membership_select_visible ON public.club_membership;
CREATE POLICY club_membership_select_visible
ON public.club_membership
FOR SELECT
USING (
    public.is_club_manager(club_id)
    OR public.is_active_club_member(club_id)
);

DROP POLICY IF EXISTS club_membership_manager_write ON public.club_membership;
CREATE POLICY club_membership_manager_write
ON public.club_membership
FOR ALL
USING (public.is_club_manager(club_id))
WITH CHECK (public.is_club_manager(club_id));

DROP POLICY IF EXISTS team_admin_all ON public.team;
CREATE POLICY team_admin_all
ON public.team
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS team_visible_to_club_or_team_members ON public.team;
CREATE POLICY team_visible_to_club_or_team_members
ON public.team
FOR SELECT
USING (
    public.is_club_manager(club_id)
    OR public.is_active_club_member(club_id)
    OR public.is_active_team_member(team_id)
);

DROP POLICY IF EXISTS team_manager_write ON public.team;
CREATE POLICY team_manager_write
ON public.team
FOR ALL
USING (
    public.is_club_manager(club_id)
    OR public.is_team_manager(team_id)
)
WITH CHECK (
    public.is_club_manager(club_id)
    OR public.is_team_manager(team_id)
);

DROP POLICY IF EXISTS team_membership_admin_all ON public.team_membership;
CREATE POLICY team_membership_admin_all
ON public.team_membership
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS team_membership_select_visible ON public.team_membership;
CREATE POLICY team_membership_select_visible
ON public.team_membership
FOR SELECT
USING (
    public.is_active_team_member(team_id)
    OR EXISTS (
        SELECT 1
        FROM public.team t
        WHERE t.team_id = team_membership.team_id
          AND (
              public.is_club_manager(t.club_id)
              OR public.is_active_club_member(t.club_id)
          )
    )
);

DROP POLICY IF EXISTS team_membership_manager_write ON public.team_membership;
CREATE POLICY team_membership_manager_write
ON public.team_membership
FOR ALL
USING (
    public.is_team_manager(team_id)
    OR EXISTS (
        SELECT 1
        FROM public.team t
        WHERE t.team_id = team_membership.team_id
          AND public.is_club_manager(t.club_id)
    )
)
WITH CHECK (
    public.is_team_manager(team_id)
    OR EXISTS (
        SELECT 1
        FROM public.team t
        WHERE t.team_id = team_membership.team_id
          AND public.is_club_manager(t.club_id)
    )
);

DROP POLICY IF EXISTS invitation_admin_all ON public.invitation;
CREATE POLICY invitation_admin_all
ON public.invitation
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS invitation_select_visible ON public.invitation;
CREATE POLICY invitation_select_visible
ON public.invitation
FOR SELECT
USING (
    invited_by = public.current_app_user_id()
    OR lower(email) = lower(coalesce(current_setting('app.user_email', true), ''))
    OR public.is_club_manager(club_id)
    OR (
        team_id IS NOT NULL
        AND public.is_team_manager(team_id)
    )
);

DROP POLICY IF EXISTS invitation_write_by_managers ON public.invitation;
CREATE POLICY invitation_write_by_managers
ON public.invitation
FOR ALL
USING (
    public.is_club_manager(club_id)
    OR (
        team_id IS NOT NULL
        AND public.is_team_manager(team_id)
    )
)
WITH CHECK (
    public.is_club_manager(club_id)
    OR (
        team_id IS NOT NULL
        AND public.is_team_manager(team_id)
    )
);
