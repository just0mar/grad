-- 050: Allow an invited user to deny their own pending invitation.

DROP POLICY IF EXISTS invitation_deny_by_invited_user ON public.invitation;
CREATE POLICY invitation_deny_by_invited_user
ON public.invitation
FOR UPDATE
USING (
    status = 'Pending'
    AND lower(email) = lower(coalesce(current_setting('app.user_email', true), ''))
)
WITH CHECK (
    status = 'Denied'
    AND accepted_by_user_id IS NULL
    AND accepted_at IS NULL
    AND lower(email) = lower(coalesce(current_setting('app.user_email', true), ''))
);
