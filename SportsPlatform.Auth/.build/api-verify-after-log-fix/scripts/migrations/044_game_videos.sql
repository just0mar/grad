-- Game videos uploaded to a game/event and stored on the server.
CREATE TABLE IF NOT EXISTS public.game_video (
    video_id           uuid PRIMARY KEY,
    event_id           uuid NOT NULL,
    team_id            uuid NOT NULL,
    added_by_user_id   uuid NOT NULL,
    added_by_role      varchar(100) NOT NULL DEFAULT '',
    title              varchar(300) NOT NULL DEFAULT '',
    file_name          varchar(300) NOT NULL DEFAULT '',
    original_file_name varchar(300) NOT NULL DEFAULT '',
    content_type       varchar(150) NOT NULL DEFAULT '',
    file_size          bigint NOT NULL DEFAULT 0,
    storage_path       text NOT NULL DEFAULT '',
    deleted_at         timestamp with time zone NULL,
    created_at         timestamp with time zone NOT NULL DEFAULT now(),
    updated_at         timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT fk_game_video_event
        FOREIGN KEY (event_id) REFERENCES public.event (event_id) ON DELETE CASCADE,
    CONSTRAINT fk_game_video_added_by
        FOREIGN KEY (added_by_user_id) REFERENCES public.users (user_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS ix_game_video_event_id ON public.game_video (event_id);
