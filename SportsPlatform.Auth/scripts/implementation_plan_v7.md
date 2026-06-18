# Equipex -- Implementation Plan v7

> Final merged implementation plan for the redesigned authentication, club, team, invitation, and membership system.
>
> This version merges:
> - v6's domain redesign: invitation-only role assignment, scoped memberships, `ClubManager` as a real stored role, `membership_status`, player constraints, removal of approval flow
> - v5's stronger implementation detail: phased execution, nested API structure, SQL/RLS direction, migration discipline, and security handling

---

## Final Decisions

| Topic | Final Decision |
|---|---|
| Registration | Any user can register an account directly |
| Approval pipeline | Removed entirely |
| Join requests | Removed entirely |
| Role assignment | Invitation links only |
| Club creation | Any registered user can create one club |
| Club creator role | Club creator automatically becomes `ClubManager` of that club |
| ClubManager enum | `ClubManager` is a valid role in `RoleNameType` and is stored in membership data |
| ClubManager scope | Club-scoped only, never a team role in the same club |
| Club-level invitations | `TeamManager` only |
| Team-level invitations | `TeamManager`, `Coach`, `FitnessCoach`, `TeamAnalyst`, `TeamDoctor`, `Player` |
| Email match on invite accept | Strictly required |
| SMTP | Real SMTP from day one using MailKit + Gmail app password |
| Role lookup table | Remove it; use PostgreSQL enum directly in membership and invitation tables |
| Player rule | One active club and one active team only; no additional roles |
| Non-player rule | Multiple clubs/teams allowed, but one role per club and one role per team |
| Admin | Global super-user outside club/team hierarchy |
| Invitation expiry default | 7 days |
| Endpoint style | Nested endpoints under clubs and teams |

---

## Role Model

### PostgreSQL / C# enum values

- `Admin`
- `ClubManager`
- `TeamManager`
- `Coach`
- `FitnessCoach`
- `TeamAnalyst`
- `TeamDoctor`
- `Player`

### Scope Rules

- `Admin` is global
- `ClubManager` is club-scoped
- `TeamManager` is team-scoped operationally, but may also exist as a club member if needed for visibility and authorization
- all other non-admin roles are team-scoped
- `ClubManager` cannot also be a team member in their own club

### Why remove the `Role` lookup table

The system has a fixed, product-defined role set. A separate `Role` table adds joins and complexity without real benefit here.

This plan proceeds with:

- PostgreSQL enum as the source of truth
- direct enum columns in membership/invitation tables
- no `Role` entity/table lookup in application logic

---

## Authority Summary

### Admin

- Full access to all clubs, teams, memberships, invitations, and domain modules

### ClubManager

- Super-user within their own club
- Can create teams in their club
- Can invite `TeamManager` at club level
- Can create a team and send team invitations themselves if needed
- Can see everything in their club
- Cannot hold team-level role memberships in their own club

### TeamManager

- Can manage only teams they belong to
- Can invite `TeamManager`, `Coach`, `FitnessCoach`, `TeamAnalyst`, `TeamDoctor`, `Player` into that team if the product allows co-managers
- If you want single-manager teams later, that is a business rule change, not an architecture change

### Coach / FitnessCoach / TeamAnalyst / TeamDoctor / Player

- Same feature authority as previously discussed
- Membership-scoped to teams
- `Player` remains the only strictly single-club, single-team role

---

## Authentication Model

### Registration

1. User registers by local auth or Google OAuth.
2. Registration creates only account/auth-provider data.
3. No approval request.
4. No role assignment.

### Login

1. User logs in.
2. System loads active memberships.
3. JWT contains:
   - global admin role if applicable
   - club membership claims
   - team membership claims

### Invitation Acceptance

1. User opens invitation link.
2. User must authenticate.
3. Authenticated email must exactly match invitation email.
4. System validates token status:
   - exists
   - not expired
   - not revoked
   - not already accepted
5. System creates membership in a single DB transaction.
6. Invitation is marked accepted.

---

## Google OAuth

Google OAuth must remain supported in the redesign.

### Final behavior

- Google sign-in creates or links the user account
- no approval request is created
- Google users can exist without any memberships yet
- membership claims only appear after invitation acceptance

### Required updates

- remove approval-related Google flow branches from `AuthService`
- keep Google profile completion only if truly needed for missing user data
- invitation acceptance must work equally for local-auth and Google-auth users

---

## Core Data Model

### 1. `club`

Fields:

- `club_id UUID PK`
- `name TEXT`
- `created_by_user_id UUID FK -> users`
- `created_at TIMESTAMPTZ`
- `updated_at TIMESTAMPTZ`
- `deleted_at TIMESTAMPTZ NULL`

Rules:

- club creator automatically gets `ClubManager`
- a user can only create one club if `ClubManager` uniqueness is enforced per user

### 2. `club_membership`

Fields:

- `club_membership_id UUID PK`
- `club_id UUID FK -> club`
- `user_id UUID FK -> users`
- `role role_name_type`
- `status membership_status`
- `invited_by_user_id UUID FK -> users NULL`
- `created_at TIMESTAMPTZ`
- `updated_at TIMESTAMPTZ`

Rules:

- unique `(club_id, user_id)`
- `ClubManager` allowed here
- `TeamManager` allowed here if you want club-level awareness for team managers
- `Player` may exist here only if you want explicit club membership separate from team membership
- partial unique: one active `ClubManager` per club
- partial unique: one active `ClubManager` club per user
- partial unique: one active player club membership total

### 3. `team`

Fields:

- `team_id UUID PK`
- `club_id UUID FK -> club`
- `team_name TEXT`
- `created_by_user_id UUID FK -> users`
- `created_at TIMESTAMPTZ`
- `updated_at TIMESTAMPTZ`
- `deleted_at TIMESTAMPTZ NULL`

Rules:

- every team belongs to a club
- nested under club in API and authorization

### 4. `team_membership`

Fields:

- `team_membership_id UUID PK`
- `team_id UUID FK -> team`
- `user_id UUID FK -> users`
- `role role_name_type`
- `status membership_status`
- `invited_by_user_id UUID FK -> users NULL`
- `created_at TIMESTAMPTZ`
- `updated_at TIMESTAMPTZ`

Rules:

- unique `(team_id, user_id)`
- allowed roles: `TeamManager`, `Coach`, `FitnessCoach`, `TeamAnalyst`, `TeamDoctor`, `Player`
- `ClubManager` must not exist here
- partial unique: one active player team membership total

### 5. `invitation`

Fields:

- `invitation_id UUID PK`
- `token TEXT UNIQUE`
- `email TEXT`
- `role role_name_type`
- `club_id UUID NULL`
- `team_id UUID NULL`
- `invited_by_user_id UUID FK -> users`
- `expires_at TIMESTAMPTZ`
- `accepted_at TIMESTAMPTZ NULL`
- `revoked_at TIMESTAMPTZ NULL`
- `created_at TIMESTAMPTZ`

Rules:

- exactly one of `club_id` or `team_id` must be non-null
- club-level invitation role must be `TeamManager`
- team-level invitation role cannot be `ClubManager`
- default expiry = `created_at + interval '7 days'`
- invitation email is immutable

### 6. `membership_status` enum

Recommended values:

- `Active`
- `Revoked`
- `Left`

---

## Membership Semantics

### Important clarification for `TeamManager`

This plan uses:

- `ClubManager` for club-wide authority
- `TeamManager` for authority over a specific team

Recommended interpretation:

- `TeamManager` authority should be derived from `team_membership`
- if needed, `club_membership` may also contain `TeamManager` rows for easier club roster queries, but team authority must come from `team_membership`

If you want to avoid duplication, keep `TeamManager` only in `team_membership` and let cross-club queries derive via joins to `team.club_id`.

Preferred implementation:

- `ClubManager` in `club_membership`
- `TeamManager` in `team_membership`
- no duplicate `TeamManager` row in `club_membership`

That keeps scopes clean.

---

## JWT and Authorization Design

### JWT claims

Include:

- `sub`
- `email`
- global admin role if applicable
- club claims
- team claims

### Recommended claim format

- `global_role=Admin`
- `club_role={clubId}:{role}`
- `team_role={teamId}:{role}`

### API authorization model

Use layered authorization:

1. authentication via JWT
2. coarse role/policy guard where useful
3. scoped service-layer checks against club/team memberships

Do not rely only on flat `[Authorize(Roles = ...)]` for club/team endpoints.

---

## RLS Strategy

RLS must be explicitly defined, not implied.

### Session variables

Middleware sets:

- `app.user_id`
- `app.user_roles`

### Recommended helper functions

```sql
CREATE OR REPLACE FUNCTION public.current_app_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(current_setting('app.user_id', true), '')::uuid
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT coalesce(current_setting('app.user_roles', true), '') LIKE '%|Admin|%'
$$;

CREATE OR REPLACE FUNCTION public.is_current_user_club_member(p_club_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.club_membership cm
        WHERE cm.club_id = p_club_id
          AND cm.user_id = public.current_app_user_id()
          AND cm.status = 'Active'
    )
$$;

CREATE OR REPLACE FUNCTION public.is_current_user_club_manager(p_club_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.club_membership cm
        WHERE cm.club_id = p_club_id
          AND cm.user_id = public.current_app_user_id()
          AND cm.role = 'ClubManager'
          AND cm.status = 'Active'
    )
$$;

CREATE OR REPLACE FUNCTION public.is_current_user_team_member(p_team_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.team_membership tm
        WHERE tm.team_id = p_team_id
          AND tm.user_id = public.current_app_user_id()
          AND tm.status = 'Active'
    )
$$;

CREATE OR REPLACE FUNCTION public.is_current_user_team_manager(p_team_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.team_membership tm
        WHERE tm.team_id = p_team_id
          AND tm.user_id = public.current_app_user_id()
          AND tm.role = 'TeamManager'
          AND tm.status = 'Active'
    )
$$;
```

### Policy direction

- club rows: club member read, club manager write, admin all
- team rows: team member read, team manager and club manager write, admin all
- invitation rows: inviter read/write, invited email accept path via service validation, admin all

---

## Email Delivery

### Final choice

Use real SMTP from day one.

### Implementation

- `MailKit`
- Gmail SMTP
- Gmail app password in config
- `IEmailService`

### Required config

- `Smtp:Host`
- `Smtp:Port`
- `Smtp:Username`
- `Smtp:Password`
- `Smtp:FromEmail`
- `Smtp:FromName`

---

## API Design

Use nested endpoints where the resource is naturally scoped.

### Auth

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /auth/logout`
- `GET /auth/google/start`
- `GET /auth/google/callback`

### Clubs

- `POST /clubs`
- `GET /clubs/my`
- `GET /clubs/{clubId}`
- `DELETE /clubs/{clubId}`

### Club invitations

- `POST /clubs/{clubId}/invitations/team-managers`
- `GET /clubs/{clubId}/invitations`

### Teams

- `POST /clubs/{clubId}/teams`
- `GET /clubs/{clubId}/teams`
- `GET /clubs/{clubId}/teams/{teamId}`
- `DELETE /clubs/{clubId}/teams/{teamId}`

### Team invitations

- `POST /clubs/{clubId}/teams/{teamId}/invitations`
- `GET /clubs/{clubId}/teams/{teamId}/invitations`

### Invitation acceptance

- `GET /invitations/{token}`
- `POST /invitations/{token}/accept`
- `POST /invitations/{token}/reject`
- `POST /invitations/{token}/revoke`

### Membership lookup

- `GET /clubs/{clubId}/members`
- `GET /clubs/{clubId}/teams/{teamId}/members`

---

## Existing Components To Remove

These are incompatible with the new model:

- `UserApprovalRequest` flow
- `ApprovalController`
- `ApprovalService`
- approval DTOs
- approval UI/API references
- `Role` entity and lookup-table-driven role resolution
- `UserRole` as the main final membership model

---

## Execution Plan

## Phase 1 -- Schema

Goal: build the new auth/membership structure alongside or replacing the old model.

Tasks:

1. Update `RoleNameType` to new enum values.
2. Add `membership_status` enum.
3. Add `club`.
4. Add `club_membership`.
5. Add `team_membership`.
6. Add `invitation`.
7. Add `club.deleted_at`.
8. Update `team` to belong to `club`.
9. Add DB constraints for player uniqueness and invitation scope.
10. Start removing `Role` table usage.

Deliverables:

- new EF entities/configurations
- SQL migrations for enums, constraints, RLS helper functions

## Phase 2 -- Services

Goal: replace approval-based role assignment with invitation-based membership assignment.

Tasks:

1. Rewrite `AuthService`:
   - registration without approval
   - login from memberships
   - refresh with membership-based claims
2. Add `ClubService`.
3. Add `TeamService` redesign for club ownership.
4. Add `InvitationService`.
5. Add `MembershipService`.
6. Add `EmailService` using MailKit.
7. Add invitation acceptance transaction flow.
8. Remove approval service logic.

## Phase 3 -- API

Goal: expose the new invitation-first API shape.

Tasks:

1. Add club endpoints.
2. Add nested team endpoints.
3. Add club invitation endpoints.
4. Add team invitation endpoints.
5. Add invitation accept/reject/revoke endpoints.
6. Remove approval endpoints.
7. Update Swagger and any test UI pages.

## Phase 4 -- DB, Security, Verification

Goal: lock down rules and verify the new system end to end.

Tasks:

1. Add RLS helper functions and policies.
2. Verify invitation token lifecycle.
3. Verify email-match enforcement.
4. Verify player one-club/one-team rule.
5. Verify ClubManager auto-creation.
6. Verify Google OAuth flow still works.
7. Remove obsolete approval schema and role lookup schema.

---

## Migration Strategy

### EF migrations

Use for:

- new entities
- columns
- indexes
- FK constraints
- enum mapping changes

### SQL migrations

Use for:

- RLS helper functions
- policies
- advanced checks and partial indexes
- data backfills

### Numbering

- `001_...`
- `002_...`
- `003_...`

and so on under `scripts/migrations/`

### Migration order

1. Add new structures
2. Switch auth/services to new structures
3. Cut APIs over
4. Remove old approval/role systems last

---

## Key Database Constraints

- unique `(club_id, user_id)` on `club_membership`
- unique `(team_id, user_id)` on `team_membership`
- partial unique index: one active `ClubManager` per club
- partial unique index: one active `ClubManager` club per user
- partial unique index: one active player club membership total
- partial unique index: one active player team membership total
- check: invitation has exactly one scope target
- check: club invitation role must equal `TeamManager`
- check: `ClubManager` not allowed in `team_membership`

---

## Testing Strategy

### Unit tests

- invitation validation
- email matching
- claim generation
- player constraint logic
- service-level authorization

### Integration tests

Use PostgreSQL-backed tests for:

- enum mappings
- membership creation
- invitation acceptance
- player uniqueness constraints
- club creation auto-membership
- SMTP service abstraction behavior

### API tests

- register/login
- create club
- invite by club manager
- invite by team manager
- accept invitation
- forbidden wrong-email acceptance
- forbidden cross-club/team actions

### OAuth tests

- Google login for existing user
- Google login for new user
- invitation acceptance after Google sign-in

---

## Estimated Impact

| Category | Estimate |
|---|---|
| New files | ~25 |
| Files to delete | ~14 |
| Files to modify | ~12 |
| Execution phases | 4 |

---

## Final Summary

This redesign changes Equipex from:

- approval-driven auth with semi-global role assignment

to:

- open registration
- invitation-only role assignment
- club-scoped and team-scoped memberships
- explicit player uniqueness rules
- scope-aware JWT authorization

This v7 plan is the implementation baseline for the new system.
