-- ============================================================
-- 017: Messaging foundation
-- ============================================================

CREATE TABLE IF NOT EXISTS public.conversation (
    conversation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    is_group boolean NOT NULL DEFAULT false,
    name varchar(200) NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.conversation_participant (
    conversation_id uuid NOT NULL REFERENCES public.conversation(conversation_id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    joined_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_conversation_participant PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.message (
    message_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id uuid NOT NULL REFERENCES public.conversation(conversation_id) ON DELETE CASCADE,
    sender_user_id uuid NOT NULL REFERENCES public.users(user_id) ON DELETE RESTRICT,
    content text NOT NULL,
    sent_at timestamptz NOT NULL DEFAULT now(),
    is_read boolean NOT NULL DEFAULT false
);

ALTER TABLE public.conversation
    ADD COLUMN IF NOT EXISTS is_group boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS name varchar(200) NULL,
    ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.conversation_participant
    ADD COLUMN IF NOT EXISTS conversation_id uuid NULL,
    ADD COLUMN IF NOT EXISTS user_id uuid NULL,
    ADD COLUMN IF NOT EXISTS joined_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.message
    ADD COLUMN IF NOT EXISTS conversation_id uuid NULL,
    ADD COLUMN IF NOT EXISTS sender_user_id uuid NULL,
    ADD COLUMN IF NOT EXISTS content text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS sent_at timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS is_read boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_conversation_participant_user
ON public.conversation_participant (user_id);

CREATE UNIQUE INDEX IF NOT EXISTS ux_conversation_participant_conversation_user
ON public.conversation_participant (conversation_id, user_id);

CREATE INDEX IF NOT EXISTS idx_message_conversation_sent
ON public.message (conversation_id, sent_at DESC);
