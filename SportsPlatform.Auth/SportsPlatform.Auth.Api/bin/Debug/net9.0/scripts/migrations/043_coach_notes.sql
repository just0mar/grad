-- Coach notes attached to a game/event, persisted with real author identity.
CREATE TABLE IF NOT EXISTS public.coach_note (
    note_id          uuid PRIMARY KEY,
    event_id         uuid NOT NULL,
    team_id          uuid NOT NULL,
    author_user_id   uuid NOT NULL,
    author_role      varchar(100) NOT NULL DEFAULT '',
    body             varchar(4000) NOT NULL DEFAULT '',
    deleted_at       timestamp with time zone NULL,
    created_at       timestamp with time zone NOT NULL DEFAULT now(),
    updated_at       timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT fk_coach_note_event
        FOREIGN KEY (event_id) REFERENCES public.event (event_id) ON DELETE CASCADE,
    CONSTRAINT fk_coach_note_author
        FOREIGN KEY (author_user_id) REFERENCES public.users (user_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS ix_coach_note_event_id ON public.coach_note (event_id);
