CREATE TABLE IF NOT EXISTS public.event_document (
    document_id uuid PRIMARY KEY,
    event_id uuid NOT NULL REFERENCES public.event(event_id) ON DELETE CASCADE,
    uploaded_by_user_id uuid NOT NULL REFERENCES public.users(user_id) ON DELETE RESTRICT,
    file_name varchar(500) NOT NULL,
    original_file_name varchar(500) NOT NULL,
    content_type varchar(200) NOT NULL,
    file_size bigint NOT NULL DEFAULT 0,
    storage_path varchar(1000) NOT NULL,
    deleted_at timestamp with time zone NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_event_document_event ON public.event_document(event_id) WHERE deleted_at IS NULL;
