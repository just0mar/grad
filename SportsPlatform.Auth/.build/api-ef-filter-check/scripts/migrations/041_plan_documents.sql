CREATE TABLE IF NOT EXISTS public.coaching_plan_document (
    document_id uuid PRIMARY KEY,
    plan_id uuid NOT NULL REFERENCES public.coaching_plan(plan_id) ON DELETE CASCADE,
    uploaded_by_user_id uuid NOT NULL REFERENCES public.users(user_id) ON DELETE RESTRICT,
    file_name varchar(500) NOT NULL,
    original_file_name varchar(500) NOT NULL,
    content_type varchar(200) NOT NULL,
    description varchar(2000) NULL,
    uploaded_by_role varchar(100) NOT NULL DEFAULT '',
    file_size bigint NOT NULL DEFAULT 0,
    storage_path varchar(1000) NOT NULL,
    deleted_at timestamp with time zone NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_coaching_plan_document_plan
    ON public.coaching_plan_document(plan_id) WHERE deleted_at IS NULL;
