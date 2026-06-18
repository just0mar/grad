ALTER TABLE public.event_document
    ADD COLUMN IF NOT EXISTS description varchar(2000) NULL,
    ADD COLUMN IF NOT EXISTS uploaded_by_role varchar(100) NOT NULL DEFAULT '';

CREATE TABLE IF NOT EXISTS public.event_plan (
    event_plan_id uuid PRIMARY KEY,
    event_id uuid NOT NULL REFERENCES public.event(event_id) ON DELETE CASCADE,
    plan_id uuid NOT NULL REFERENCES public.coaching_plan(plan_id) ON DELETE CASCADE,
    linked_by_user_id uuid NOT NULL REFERENCES public.users(user_id) ON DELETE RESTRICT,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT uq_event_plan_event_plan UNIQUE (event_id, plan_id)
);

CREATE INDEX IF NOT EXISTS ix_event_plan_event ON public.event_plan(event_id);
