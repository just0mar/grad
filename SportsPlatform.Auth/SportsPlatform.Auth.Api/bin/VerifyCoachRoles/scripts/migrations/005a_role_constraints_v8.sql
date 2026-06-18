-- ============================================================
-- 005a: Constraints/indexes that depend on the new v8 role enum
-- Runs after 005 so the new enum labels are already committed.
-- ============================================================

-- Club membership may only store TeamManager in v8.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_club_membership_role_teammanager_only'
    ) THEN
        ALTER TABLE public.club_membership
            ADD CONSTRAINT ck_club_membership_role_teammanager_only
            CHECK (role = 'TeamManager');
    END IF;
END $$;

-- Team membership may only store team-scoped roles.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_team_membership_role_allowed'
    ) THEN
        ALTER TABLE public.team_membership
            ADD CONSTRAINT ck_team_membership_role_allowed
            CHECK (
                role IN (
                    'TeamManager',
                    'Coach',
                    'FitnessCoach',
                    'TeamAnalyst',
                    'TeamDoctor',
                    'Player'
                )
            );
    END IF;
END $$;

-- Invitation role/scope rules.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_invitation_scope_role_rules'
    ) THEN
        ALTER TABLE public.invitation
            ADD CONSTRAINT ck_invitation_scope_role_rules
            CHECK (
                (
                    team_id IS NULL
                    AND role = 'TeamManager'
                )
                OR
                (
                    team_id IS NOT NULL
                    AND role IN (
                        'TeamManager',
                        'Coach',
                        'FitnessCoach',
                        'TeamAnalyst',
                        'TeamDoctor',
                        'Player'
                    )
                )
            );
    END IF;
END $$;

-- A Player may only have one active team membership total.
CREATE UNIQUE INDEX IF NOT EXISTS ux_team_membership_active_player_single_team
ON public.team_membership (user_id)
WHERE role = 'Player' AND status = 'Active';
