-- 033: Optional announcement image URL

ALTER TABLE public.announcement
    ADD COLUMN IF NOT EXISTS image_url varchar(500);
