-- ============================================================
-- 035: Message read receipts
--   Tracks which conversation participants have seen each message.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.message_read_receipt (
    message_id uuid        NOT NULL REFERENCES public.message(message_id) ON DELETE CASCADE,
    user_id    uuid        NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    read_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_message_read_receipt PRIMARY KEY (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_message_read_receipt_user
ON public.message_read_receipt (user_id);
