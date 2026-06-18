-- ============================================================
-- 020: Fix invitation acceptance RLS after legacy role removal
-- ============================================================

-- Migration 003 left transitional helper functions in place that referenced
-- public.user_role and public.team_manager. Migration 007 removes those
-- legacy tables, so replace the helpers with the v8 membership model.

CREATE OR REPLACE FUNCTION public.is_current_user_team_manager(p_team_id uuid)
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

CREATE OR REPLACE FUNCTION public.is_current_user_team_member(p_team_id uuid)
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

CREATE OR REPLACE FUNCTION public.has_pending_club_invitation_for_current_user(
    p_club_id uuid,
    p_role public.role_name_type
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.invitation i
        WHERE i.club_id = p_club_id
          AND i.team_id IS NULL
          AND i.role = p_role
          AND i.status = 'Pending'
          AND lower(i.email) = lower(coalesce(current_setting('app.user_email', true), ''))
    )
$$;

CREATE OR REPLACE FUNCTION public.has_pending_club_invitation_for_current_user(p_club_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.invitation i
        WHERE i.club_id = p_club_id
          AND i.team_id IS NULL
          AND i.status = 'Pending'
          AND lower(i.email) = lower(coalesce(current_setting('app.user_email', true), ''))
    )
$$;

CREATE OR REPLACE FUNCTION public.has_pending_team_invitation_for_current_user(
    p_team_id uuid,
    p_role public.role_name_type
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.invitation i
        WHERE i.team_id = p_team_id
          AND i.role = p_role
          AND i.status = 'Pending'
          AND lower(i.email) = lower(coalesce(current_setting('app.user_email', true), ''))
    )
$$;

CREATE OR REPLACE FUNCTION public.has_pending_team_invitation_for_current_user(p_team_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.invitation i
        WHERE i.team_id = p_team_id
          AND i.status = 'Pending'
          AND lower(i.email) = lower(coalesce(current_setting('app.user_email', true), ''))
    )
$$;

-- Allow the invited account to mark its own pending invitation accepted.
DROP POLICY IF EXISTS invitation_accept_by_invited_user ON public.invitation;
CREATE POLICY invitation_accept_by_invited_user
ON public.invitation
FOR UPDATE
USING (
    status = 'Pending'
    AND lower(email) = lower(coalesce(current_setting('app.user_email', true), ''))
)
WITH CHECK (
    status = 'Accepted'
    AND accepted_by_user_id = public.current_app_user_id()
    AND accepted_at IS NOT NULL
    AND lower(email) = lower(coalesce(current_setting('app.user_email', true), ''))
);

-- Allow the invited account to create or reactivate only its own membership
-- when a matching pending invitation exists.
DROP POLICY IF EXISTS club_membership_accept_invitation_insert ON public.club_membership;
CREATE POLICY club_membership_accept_invitation_insert
ON public.club_membership
FOR INSERT
WITH CHECK (
    user_id = public.current_app_user_id()
    AND status = 'Active'
    AND public.has_pending_club_invitation_for_current_user(club_id, role)
);

DROP POLICY IF EXISTS club_membership_accept_invitation_update ON public.club_membership;
CREATE POLICY club_membership_accept_invitation_update
ON public.club_membership
FOR UPDATE
USING (
    user_id = public.current_app_user_id()
    AND public.has_pending_club_invitation_for_current_user(club_id)
)
WITH CHECK (
    user_id = public.current_app_user_id()
    AND status = 'Active'
    AND public.has_pending_club_invitation_for_current_user(club_id, role)
);

DROP POLICY IF EXISTS team_membership_accept_invitation_insert ON public.team_membership;
CREATE POLICY team_membership_accept_invitation_insert
ON public.team_membership
FOR INSERT
WITH CHECK (
    user_id = public.current_app_user_id()
    AND status = 'Active'
    AND public.has_pending_team_invitation_for_current_user(team_id, role)
);

DROP POLICY IF EXISTS team_membership_accept_invitation_update ON public.team_membership;
CREATE POLICY team_membership_accept_invitation_update
ON public.team_membership
FOR UPDATE
USING (
    user_id = public.current_app_user_id()
    AND public.has_pending_team_invitation_for_current_user(team_id)
)
WITH CHECK (
    user_id = public.current_app_user_id()
    AND status = 'Active'
    AND public.has_pending_team_invitation_for_current_user(team_id, role)
);
