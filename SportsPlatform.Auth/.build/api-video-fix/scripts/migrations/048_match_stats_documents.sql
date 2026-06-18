-- Typed raw stats PDFs per match (box score, plus/minus, lineup, play-by-play)
-- for the "Ask Equipo" chatbot / prediction microservice. Replaces the implicit
-- single-PDF model (match_stats.raw_pdf_path) with one row per PDF type, while
-- the legacy raw_pdf_* columns on match_stats continue to mirror the box score.
CREATE TABLE IF NOT EXISTS public.match_stats_document (
    document_id    uuid PRIMARY KEY,
    match_stats_id uuid NOT NULL,
    pdf_type       varchar(40) NOT NULL DEFAULT 'box_score',
    storage_path   varchar(500) NOT NULL DEFAULT '',
    file_name      varchar(300) NOT NULL DEFAULT '',
    content_type   varchar(150) NOT NULL DEFAULT 'application/pdf',
    file_size      bigint NOT NULL DEFAULT 0,
    extracted_text text NULL,
    uploaded_at    timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT fk_match_stats_document_match_stats
        FOREIGN KEY (match_stats_id) REFERENCES public.match_stats (match_stats_id) ON DELETE CASCADE
);

-- At most one PDF of each type per match.
CREATE UNIQUE INDEX IF NOT EXISTS ux_match_stats_document_match_type
    ON public.match_stats_document (match_stats_id, pdf_type);
