ALTER TABLE public.club
    ADD COLUMN IF NOT EXISTS location varchar(200) NULL,
    ADD COLUMN IF NOT EXISTS location_latitude double precision NULL,
    ADD COLUMN IF NOT EXISTS location_longitude double precision NULL;

ALTER TABLE public.event
    ADD COLUMN IF NOT EXISTS location_latitude double precision NULL,
    ADD COLUMN IF NOT EXISTS location_longitude double precision NULL;

ALTER TABLE public.message
    ADD COLUMN IF NOT EXISTS location_latitude double precision NULL,
    ADD COLUMN IF NOT EXISTS location_longitude double precision NULL,
    ADD COLUMN IF NOT EXISTS location_label varchar(200) NULL;

CREATE INDEX IF NOT EXISTS ix_club_location_coordinates
    ON public.club(location_latitude, location_longitude)
    WHERE location_latitude IS NOT NULL AND location_longitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_event_location_coordinates
    ON public.event(location_latitude, location_longitude)
    WHERE location_latitude IS NOT NULL AND location_longitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_message_location_coordinates
    ON public.message(location_latitude, location_longitude)
    WHERE location_latitude IS NOT NULL AND location_longitude IS NOT NULL;
