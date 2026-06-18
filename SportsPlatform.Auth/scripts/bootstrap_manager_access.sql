-- ============================================================
-- BOOTSTRAP MANAGER ACCESS (DEV ONLY)
-- Usage:
--   1) Register a normal user first via POST /auth/register
--   2) Update v_email below to that user's email
--   3) Run this script once against your database
--   4) Login via POST /auth/login and use returned AccessToken
-- ============================================================

DO $$
DECLARE
    v_email   TEXT := 'omar.elsaid253@gmail.com'; -- CHANGE THIS
    v_user_id UUID;
    v_role_id UUID;
BEGIN
    SELECT u.user_id
    INTO v_user_id
    FROM users u
    WHERE u.email = v_email;

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User with email % was not found. Register first, then rerun.', v_email;
    END IF;

    SELECT r.role_id
    INTO v_role_id
    FROM role r
    WHERE r.role_name = 'Manager'::role_name_type
    LIMIT 1;

    IF v_role_id IS NULL THEN
        INSERT INTO role (role_id, role_name, created_at, updated_at)
        VALUES (gen_random_uuid(), 'Manager'::role_name_type, NOW(), NOW())
        RETURNING role_id INTO v_role_id;
    END IF;

    UPDATE user_approval_request ar
    SET status = 'Approved'::approval_request_status,
        reviewed_by = v_user_id,
        reviewed_at = NOW(),
        notes = COALESCE(ar.notes, 'Auto-approved for dev manager bootstrap.'),
        updated_at = NOW()
    WHERE ar.user_id = v_user_id
      AND ar.status = 'Pending'::approval_request_status;

    IF NOT EXISTS (
        SELECT 1
        FROM user_role ur
        WHERE ur.user_id = v_user_id
          AND ur.role_id = v_role_id
    ) THEN
        INSERT INTO user_role
            (user_role_id, user_id, role_id, team_id, status, assigned_by, assigned_at, created_at, updated_at)
        VALUES
            (gen_random_uuid(), v_user_id, v_role_id, NULL, 'Approved'::user_role_status, v_user_id, NOW(), NOW(), NOW());
    ELSE
        UPDATE user_role ur
        SET status = 'Approved'::user_role_status,
            assigned_by = COALESCE(ur.assigned_by, v_user_id),
            assigned_at = COALESCE(ur.assigned_at, NOW()),
            updated_at = NOW()
        WHERE ur.user_id = v_user_id
          AND ur.role_id = v_role_id;
    END IF;
END $$;

-- Verify role assignment
SELECT u.email,
       r.role_name,
       ur.status,
       ur.assigned_at
FROM user_role ur
JOIN users u ON u.user_id = ur.user_id
JOIN role r ON r.role_id = ur.role_id
WHERE u.email = 'omar.elsaid253@gmail.com'; -- SAME EMAIL AS ABOVE
