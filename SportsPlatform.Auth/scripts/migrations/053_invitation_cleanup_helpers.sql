-- 053: Keep invitation history for a short retention window, then delete
-- finalized invitations. Security definer keeps cleanup independent from
-- request-scoped RLS settings.

CREATE OR REPLACE FUNCTION public.deny_invitation_for_email(
    p_token text,
    p_email text
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    WITH updated AS (
        UPDATE public.invitation
        SET
            status = 'Denied'::public.invitation_status,
            resolved_at = now()
        WHERE token = p_token
          AND status = 'Pending'::public.invitation_status
          AND expires_at > now()
          AND lower(email) = lower(p_email)
        RETURNING 1
    )
    SELECT EXISTS (SELECT 1 FROM updated);
$$;

CREATE OR REPLACE FUNCTION public.cleanup_finalized_invitations(
    p_cutoff timestamptz
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    deleted_count integer;
BEGIN
    DELETE FROM public.invitation
    WHERE resolved_at IS NOT NULL
      AND resolved_at < p_cutoff
      AND status IN (
          'Accepted'::public.invitation_status,
          'Expired'::public.invitation_status,
          'Cancelled'::public.invitation_status,
          'Denied'::public.invitation_status
      );

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;
