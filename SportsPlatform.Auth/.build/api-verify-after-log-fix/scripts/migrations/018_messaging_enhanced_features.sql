-- ============================================================
-- 018: Messaging enhanced features
--   Adds edit/delete, media attachments, reactions
-- ============================================================

-- Add new columns to message table
ALTER TABLE public.message
    ADD COLUMN IF NOT EXISTS edited_at        timestamptz          NULL,
    ADD COLUMN IF NOT EXISTS is_deleted       boolean     NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS message_type     varchar(50) NOT NULL DEFAULT 'text',
    ADD COLUMN IF NOT EXISTS media_url        varchar(500)         NULL,
    ADD COLUMN IF NOT EXISTS media_file_name  varchar(300)         NULL;

-- Message reactions table
CREATE TABLE IF NOT EXISTS public.message_reaction (
    reaction_id uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id  uuid        NOT NULL REFERENCES public.message(message_id) ON DELETE CASCADE,
    user_id     uuid        NOT NULL REFERENCES public.users(user_id)    ON DELETE CASCADE,
    emoji       varchar(50) NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- One reaction per emoji per user per message
CREATE UNIQUE INDEX IF NOT EXISTS ux_message_reaction_msg_user_emoji
ON public.message_reaction (message_id, user_id, emoji);
