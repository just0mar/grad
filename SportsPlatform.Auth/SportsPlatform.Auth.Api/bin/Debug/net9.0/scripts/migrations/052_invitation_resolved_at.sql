-- 052: Track when an invitation reaches a final state so finalized invites can
-- be retained briefly, then cleaned up automatically.

ALTER TABLE public.invitation
    ADD COLUMN IF NOT EXISTS resolved_at timestamptz NULL;

UPDATE public.invitation
SET resolved_at = COALESCE(accepted_at, expires_at, created_at)
WHERE resolved_at IS NULL
  AND status IN (
      'Accepted'::public.invitation_status,
      'Expired'::public.invitation_status,
      'Cancelled'::public.invitation_status,
      'Denied'::public.invitation_status
  );

CREATE INDEX IF NOT EXISTS idx_invitation_finalized_cleanup
ON public.invitation (resolved_at)
WHERE status IN (
    'Accepted'::public.invitation_status,
    'Expired'::public.invitation_status,
    'Cancelled'::public.invitation_status,
    'Denied'::public.invitation_status
);
