-- 051: Helper used by the API to deny an invitation after app-level checks.
-- Runs as a definer function so the recipient-deny write is not blocked by
-- unrelated manager-only invitation write policies.

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
        SET status = 'Denied'::public.invitation_status
        WHERE token = p_token
          AND status = 'Pending'::public.invitation_status
          AND expires_at > now()
          AND lower(email) = lower(p_email)
        RETURNING 1
    )
    SELECT EXISTS (SELECT 1 FROM updated);
$$;
