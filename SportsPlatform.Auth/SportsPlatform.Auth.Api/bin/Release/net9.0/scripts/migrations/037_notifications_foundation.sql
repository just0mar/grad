CREATE TABLE IF NOT EXISTS public.app_notification (
    notification_id uuid PRIMARY KEY,
    recipient_user_id uuid NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    actor_user_id uuid NULL REFERENCES public.users(user_id) ON DELETE SET NULL,
    club_id uuid NULL REFERENCES public.club(club_id) ON DELETE SET NULL,
    team_id uuid NULL REFERENCES public.team(team_id) ON DELETE SET NULL,
    type varchar(80) NOT NULL,
    priority varchar(30) NOT NULL DEFAULT 'Normal',
    delivery_policy varchar(40) NOT NULL DEFAULT 'RealtimeIfConnected',
    title varchar(200) NOT NULL,
    body varchar(1000) NOT NULL,
    target_type varchar(80) NULL,
    target_id uuid NULL,
    target_route varchar(300) NULL,
    metadata_json jsonb NULL,
    unique_key varchar(250) NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    read_at timestamptz NULL,
    email_sent_at timestamptz NULL
);

CREATE INDEX IF NOT EXISTS ix_app_notification_recipient_created
    ON public.app_notification(recipient_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_app_notification_recipient_read
    ON public.app_notification(recipient_user_id, read_at);

CREATE INDEX IF NOT EXISTS ix_app_notification_team
    ON public.app_notification(team_id);

CREATE INDEX IF NOT EXISTS ix_app_notification_type
    ON public.app_notification(type);

CREATE UNIQUE INDEX IF NOT EXISTS ux_app_notification_unique_key
    ON public.app_notification(unique_key)
    WHERE unique_key IS NOT NULL;
