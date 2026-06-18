-- ============================================================
-- 004: Club / membership / invitation foundation
-- Transitional additive migration for the v8 redesign.
-- Keeps legacy approval/role tables intact for now.
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'invitation_status'
          AND n.nspname = 'public'
    ) THEN
        CREATE TYPE public.invitation_status AS ENUM (
            'Pending',
            'Accepted',
            'Expired',
            'Cancelled'
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typname = 'membership_status'
          AND n.nspname = 'public'
    ) THEN
        CREATE TYPE public.membership_status AS ENUM (
            'Active',
            'Revoked',
            'Left'
        );
    END IF;
END $$;

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS is_admin boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS public.club (
    club_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    created_by uuid NOT NULL REFERENCES public.users(user_id) ON DELETE RESTRICT,
    deleted_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_club_created_by ON public.club (created_by);

ALTER TABLE public.team
    ADD COLUMN IF NOT EXISTS club_id uuid,
    ADD COLUMN IF NOT EXISTS created_by uuid;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'team_club_id_fkey'
    ) THEN
        ALTER TABLE public.team
            ADD CONSTRAINT team_club_id_fkey
            FOREIGN KEY (club_id) REFERENCES public.club(club_id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'team_created_by_fkey'
    ) THEN
        ALTER TABLE public.team
            ADD CONSTRAINT team_created_by_fkey
            FOREIGN KEY (created_by) REFERENCES public.users(user_id) ON DELETE RESTRICT;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_team_club_id ON public.team (club_id);

CREATE TABLE IF NOT EXISTS public.club_membership (
    club_membership_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id uuid NOT NULL REFERENCES public.club(club_id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    role public.role_name_type NOT NULL,
    status public.membership_status NOT NULL DEFAULT 'Active',
    invited_by uuid REFERENCES public.users(user_id) ON DELETE SET NULL,
    joined_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_club_membership UNIQUE (club_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_club_membership_user_id ON public.club_membership (user_id);

CREATE TABLE IF NOT EXISTS public.team_membership (
    team_membership_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id uuid NOT NULL REFERENCES public.team(team_id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    role public.role_name_type NOT NULL,
    status public.membership_status NOT NULL DEFAULT 'Active',
    invited_by uuid REFERENCES public.users(user_id) ON DELETE SET NULL,
    joined_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_team_membership UNIQUE (team_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_team_membership_user_id ON public.team_membership (user_id);

CREATE TABLE IF NOT EXISTS public.invitation (
    invitation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    token text NOT NULL UNIQUE,
    email text NOT NULL,
    role public.role_name_type NOT NULL,
    club_id uuid NOT NULL REFERENCES public.club(club_id) ON DELETE CASCADE,
    team_id uuid NULL REFERENCES public.team(team_id) ON DELETE CASCADE,
    invited_by uuid NOT NULL REFERENCES public.users(user_id) ON DELETE RESTRICT,
    status public.invitation_status NOT NULL DEFAULT 'Pending',
    expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
    accepted_at timestamptz NULL,
    accepted_by_user_id uuid NULL REFERENCES public.users(user_id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invitation_email ON public.invitation (email);
CREATE INDEX IF NOT EXISTS idx_invitation_club_id ON public.invitation (club_id);
CREATE INDEX IF NOT EXISTS idx_invitation_team_id ON public.invitation (team_id);
