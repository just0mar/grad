-- Short-lived password reset challenges for the "forgot password" flow.
-- Stores a hashed 6-digit OTP and a hashed opaque link token. Single-use,
-- expires after a short window.
CREATE TABLE IF NOT EXISTS public.password_reset_code (
    id             uuid PRIMARY KEY,
    user_id        uuid NOT NULL,
    code_hash      text NOT NULL DEFAULT '',
    token_hash     text NOT NULL DEFAULT '',
    attempt_count  integer NOT NULL DEFAULT 0,
    expires_at     timestamp with time zone NOT NULL,
    consumed_at    timestamp with time zone NULL,
    created_at     timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT fk_password_reset_code_user
        FOREIGN KEY (user_id) REFERENCES public.users (user_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_password_reset_code_user_id ON public.password_reset_code (user_id);
