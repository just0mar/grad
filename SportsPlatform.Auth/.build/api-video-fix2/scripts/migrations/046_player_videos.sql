-- Player performance/analysis videos uploaded for a player and stored on the
-- server. A player can have many videos.
CREATE TABLE IF NOT EXISTS public.player_video (
    video_id           uuid PRIMARY KEY,
    player_user_id     uuid NOT NULL,
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
    CONSTRAINT fk_player_video_player
        FOREIGN KEY (player_user_id) REFERENCES public.users (user_id) ON DELETE RESTRICT,
    CONSTRAINT fk_player_video_added_by
        FOREIGN KEY (added_by_user_id) REFERENCES public.users (user_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS ix_player_video_player_user_id ON public.player_video (player_user_id);
CREATE INDEX IF NOT EXISTS ix_player_video_team_id ON public.player_video (team_id);
