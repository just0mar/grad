-- ============================================================
-- 022: Medical document requests + custom fitness tests
-- ============================================================

ALTER TABLE public.fitness_record
    ADD COLUMN IF NOT EXISTS custom_test_name varchar(100) NULL,
    ADD COLUMN IF NOT EXISTS custom_test_result numeric(10,2) NULL;

ALTER TABLE public.medical_record
    ADD COLUMN IF NOT EXISTS recovery_tips text NULL;

CREATE TABLE IF NOT EXISTS public.medical_document_request (
    request_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    record_id uuid NOT NULL REFERENCES public.medical_record(record_id) ON DELETE CASCADE,
    document_name varchar(200) NOT NULL,
    note text NULL,
    status varchar(20) NOT NULL DEFAULT 'Pending',
    requested_by uuid NOT NULL REFERENCES public.users(user_id) ON DELETE RESTRICT,
    uploaded_by uuid NULL REFERENCES public.users(user_id) ON DELETE SET NULL,
    original_file_name varchar(255) NULL,
    stored_file_name varchar(255) NULL,
    content_type varchar(100) NULL,
    file_size_bytes bigint NULL,
    requested_at timestamptz NOT NULL DEFAULT now(),
    uploaded_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_medical_document_request_status
        CHECK (status IN ('Pending', 'Uploaded'))
);

ALTER TABLE public.medical_document_request
    ADD COLUMN IF NOT EXISTS note text NULL,
    ADD COLUMN IF NOT EXISTS uploaded_by uuid NULL,
    ADD COLUMN IF NOT EXISTS original_file_name varchar(255) NULL,
    ADD COLUMN IF NOT EXISTS stored_file_name varchar(255) NULL,
    ADD COLUMN IF NOT EXISTS content_type varchar(100) NULL,
    ADD COLUMN IF NOT EXISTS file_size_bytes bigint NULL,
    ADD COLUMN IF NOT EXISTS uploaded_at timestamptz NULL,
    ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'medical_document_request_record_id_fkey'
    ) THEN
        ALTER TABLE public.medical_document_request
            ADD CONSTRAINT medical_document_request_record_id_fkey
            FOREIGN KEY (record_id) REFERENCES public.medical_record(record_id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'medical_document_request_requested_by_fkey'
    ) THEN
        ALTER TABLE public.medical_document_request
            ADD CONSTRAINT medical_document_request_requested_by_fkey
            FOREIGN KEY (requested_by) REFERENCES public.users(user_id) ON DELETE RESTRICT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'medical_document_request_uploaded_by_fkey'
    ) THEN
        ALTER TABLE public.medical_document_request
            ADD CONSTRAINT medical_document_request_uploaded_by_fkey
            FOREIGN KEY (uploaded_by) REFERENCES public.users(user_id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ck_medical_document_request_status'
    ) THEN
        ALTER TABLE public.medical_document_request
            ADD CONSTRAINT ck_medical_document_request_status
            CHECK (status IN ('Pending', 'Uploaded'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_medical_document_request_record
ON public.medical_document_request (record_id, requested_at DESC);

CREATE INDEX IF NOT EXISTS idx_medical_document_request_status
ON public.medical_document_request (status);
