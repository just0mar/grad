-- Persist the raw stats PDF on match_stats so the future "Ask Equipo" chatbot
-- can be served the original document and a pre-extracted text context.
ALTER TABLE public.match_stats
    ADD COLUMN IF NOT EXISTS raw_pdf_path varchar(500) NULL,
    ADD COLUMN IF NOT EXISTS raw_pdf_file_name varchar(300) NULL,
    ADD COLUMN IF NOT EXISTS raw_pdf_content_type varchar(150) NULL,
    ADD COLUMN IF NOT EXISTS raw_pdf_size bigint NULL,
    ADD COLUMN IF NOT EXISTS raw_pdf_uploaded_at timestamp with time zone NULL,
    ADD COLUMN IF NOT EXISTS extracted_text text NULL;
