# Equipex -- Implementation Plan v6

> Clean baseline for the redesigned authentication, club, team, invitation, and membership system.

---

## Final Product Decisions

These decisions are treated as final in this plan.

| Topic | Final Decision |
|---|---|
| Registration model | Any user can register an account directly |
| Role assignment model | Roles are assigned only through invitation links |
| Approval pipeline | Removed entirely |
| Join requests | Removed entirely |
| Club creator role | Club creator automatically becomes `ClubManager` |
| Club Manager scope | A user can only be `ClubManager` of one club they created |
| Club-level invitation roles | `TeamManager` only |
| Team-level invitation roles | `Coach`, `FitnessCoach`, `TeamAnalyst`, `TeamDoctor`, `Player` |
| Email acceptance rule | Invitation can only be accepted by the registered user with the same email |
| Club Manager as team member | Not allowed in their own club |
| Player constraint | Player can belong to only one club and one team at a time |
| Non-player memberships | Can belong to multiple clubs and teams, with different roles |
| Admin | Global super-user outside club/team hierarchy |
| SMTP | Real SMTP from day one using MailKit + Gmail app password |
| Role storage | Remove `Role` lookup table and store role as PostgreSQL enum directly in membership tables |

---

## Roles

Use a single PostgreSQL enum and C# enum with these values:

- `Admin`
- `ClubManager`
- `TeamManager`
- `Coach`
- `FitnessCoach`
- `TeamAnalyst`
- `TeamDoctor`
- `Player`

### Notes

- `Admin` is global.
- `ClubManager` is valid and stored as a normal role value.
- `ClubManager` is club-scoped, not team-scoped.
- `ClubManager` must never appear in team membership rows.

---

## Core Authority Model

### Admin

- Full super-user access across the whole platform.
- Exists outside club/team hierarchy.

### Club Manager

- Super-user within their own club.
- Can create teams in their club.
- Can invite `TeamManager` at club level.
- Can also create teams themselves and send team invitations when needed.
- Cannot be assigned a team-level role in their own club.

### Team Manager

- Can manage only teams they belong to.
- Can invite `Coach`, `FitnessCoach`, `TeamAnalyst`, `TeamDoctor`, and `Player` to their team.

### Coach

- Team-scoped role.
- Same business authority as previously discussed for coaching features.

### Fitness Coach

- Team-scoped role.
- Same business authority as previously discussed for fitness features.

### Team Analyst

- Team-scoped role.
- Same business authority as previously discussed for stats and analytics.

### Team Doctor

- Team-scoped role.
- Same business authority as previously discussed for medical features.

### Player

- Team-scoped role.
- Can only have one active club membership and one active team membership total.
- Cannot hold any other role at the same time.

---

## Membership Rules

### Global Rules

- Roles are not bound to the account globally.
- Roles are bound to memberships.
- Same user may have different roles in different clubs or teams.
- Within a single club, a user can only have one club membership row.
- Within a single team, a user can only have one team membership row.

### Player Rules

- A Player can only belong to one club at a time.
- A Player can only belong to one team at a time.
- A Player cannot hold multiple roles.

### Non-Player Rules

- Non-player users can belong to multiple clubs.
- Non-player users can belong to multiple teams.
- They may hold different roles in different memberships.
- They are still limited to one role per club and one role per team.

### Club Manager Rules

- A user can only be `ClubManager` of one club.
- `ClubManager` is granted automatically when creating a club.
- `ClubManager` cannot also be a team member in the same club.

---

## Authentication Flow

### Registration

1. Any user registers with email/password or Google.
2. Registration creates only the user account and auth provider records.
3. No approval request is created.
4. No role is assigned at registration time.

### Login

1. User logs in with existing credentials.
2. System loads active club memberships and team memberships.
3. JWT is generated from those memberships plus global `Admin` if present.

### Invitation Acceptance

1. User receives invitation link by email.
2. User signs in or registers with the invited email.
3. System verifies the logged-in email exactly matches the invitation email.
4. If valid and not expired, the invitation is accepted.
5. Appropriate club or team membership is created.
6. Invitation becomes consumed and cannot be reused.

---

## Invitation Model

Use one invitation table with scoped target fields.

### Rules

- An invitation targets either a club or a team, never both.
- Club invitations may only assign `TeamManager`.
- Team invitations may assign `Coach`, `FitnessCoach`, `TeamAnalyst`, `TeamDoctor`, or `Player`.
- Invitation token must be single-use.
- Invitation must expire.
- Invitation must store invited email and be accepted only by that email.

---

## Recommended Database Design

### 1. `club`

Fields:

- `club_id UUID PK`
- `name TEXT`
- `created_by_user_id UUID FK -> users`
- `created_at`
- `updated_at`

Rules:

- creator automatically gets `ClubManager` membership
- one club per `ClubManager` creator

### 2. `club_membership`

Fields:

- `club_membership_id UUID PK`
- `club_id UUID FK -> club`
- `user_id UUID FK -> users`
- `role role_name_type`
- `status membership_status`
- `invited_by_user_id UUID FK -> users NULL`
- `created_at`
- `updated_at`

Rules:

- unique `(club_id, user_id)`
- `ClubManager` allowed here
- `TeamManager` allowed here
- other roles should not be stored here
- only one `ClubManager` per club
- one user cannot be `ClubManager` of multiple clubs
- `Player` cannot have more than one active club membership total

### 3. `team`

Fields:

- `team_id UUID PK`
- `club_id UUID FK -> club`
- `team_name TEXT`
- `created_by_user_id UUID FK -> users`
- `created_at`
- `updated_at`
- `deleted_at NULL`

Rules:

- every team belongs to a club
- only club manager or team manager with authority can create teams

### 4. `team_membership`

Fields:

- `team_membership_id UUID PK`
- `team_id UUID FK -> team`
- `user_id UUID FK -> users`
- `role role_name_type`
- `status membership_status`
- `invited_by_user_id UUID FK -> users NULL`
- `created_at`
- `updated_at`

Rules:

- unique `(team_id, user_id)`
- allowed roles: `TeamManager`, `Coach`, `FitnessCoach`, `TeamAnalyst`, `TeamDoctor`, `Player`
- `ClubManager` is not allowed here
- `Player` cannot have more than one active team membership total

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
- `created_at`

Rules:

- exactly one of `club_id` or `team_id` must be non-null
- if `club_id` is set, role must be `TeamManager`
- if `team_id` is set, role must not be `ClubManager`
- cannot accept expired, revoked, or already accepted invitations

### 6. `membership_status` enum

Recommended values:

- `Active`
- `Revoked`
- `Left`

---

## Existing Structures To Remove

These no longer fit the new product model:

- `UserApprovalRequest` entity and table usage
- `ApprovalController`
- `ApprovalService`
- approval DTOs and endpoints
- approval-based login gating
- `Role` lookup table and `role` joins
- `UserRole` table design as the main membership model

---

## JWT Design

Do not model auth as one flat global role list except for `Admin`.

### JWT Should Include

- `sub`
- `email`
- global admin claim if user is `Admin`
- club membership claims
- team membership claims

### Recommended Claim Shape

- `global_role: Admin`
- `club_role: {clubId}:{role}`
- `team_role: {teamId}:{role}`

### Important Consequence

Authorization should become scope-aware:

- API endpoints for clubs must validate club membership
- API endpoints for teams must validate team membership
- service-layer authorization is required for most endpoints
- simple `[Authorize(Roles=...)]` alone will not be enough for scoped logic

---

## Email Delivery

### Final Choice

Use real SMTP from day one.

### Recommended Implementation

- `MailKit`
- Gmail SMTP
- Gmail app password stored in config
- `IEmailService` abstraction

### Config

Recommended settings:

- `Smtp:Host`
- `Smtp:Port`
- `Smtp:Username`
- `Smtp:Password`
- `Smtp:FromEmail`
- `Smtp:FromName`

---

## Execution Plan

### Phase 1 -- Schema Redesign

Goal: replace approval-centric auth schema with club/team membership schema.

Tasks:

1. Add `club` table and entity.
2. Add `club_membership` table and entity.
3. Add `team_membership` table and entity.
4. Redesign `team` so every team belongs to a club.
5. Add `invitation` table and entity.
6. Add `membership_status` enum.
7. Update `role_name_type` enum to new roles.
8. Remove `Role` table usage from code and schema.
9. Mark approval-related tables and code for removal.

Estimated outcome:

- new files: entity/configuration/migration files
- major schema break from previous model

### Phase 2 -- Service Layer Redesign

Goal: make auth and authorization membership-based.

Tasks:

1. Rewrite `AuthService` so registration creates only the account.
2. Rewrite login so JWT is built from memberships, not approval state.
3. Add `ClubService`.
4. Add `InvitationService`.
5. Add `MembershipService`.
6. Add `EmailService`.
7. Add invitation acceptance logic with email-match enforcement.
8. Add club creation flow that auto-creates `ClubManager` membership.
9. Remove `ApprovalService`.

### Phase 3 -- API Redesign

Goal: expose clean endpoints for clubs, teams, invitations, and memberships.

Recommended endpoints:

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /clubs`
- `GET /clubs/my`
- `POST /clubs/{clubId}/invite-team-manager`
- `POST /teams`
- `GET /teams/my`
- `POST /teams/{teamId}/invite`
- `POST /invitations/accept`
- `POST /invitations/reject`
- `GET /invitations/my-pending`

Remove:

- approval endpoints
- onboarding approval endpoints

### Phase 4 -- DB Rules, Verification, Cleanup

Goal: enforce all critical business rules and validate the redesign.

Tasks:

1. Enforce single club manager per club.
2. Enforce one-club-per-player rule.
3. Enforce one-team-per-player rule.
4. Enforce team or club target exclusivity on invitations.
5. Enforce invitation email matching.
6. Enforce single-use invitation tokens.
7. Enforce no `ClubManager` rows in team memberships.
8. Remove obsolete approval and role-lookup code/files.
9. Verify token generation and scoped authorization.
10. Verify SMTP email sending.

---

## Database Constraints To Enforce

These should be enforced in DB as much as possible, not only in services.

- unique `(club_id, user_id)` on `club_membership`
- unique `(team_id, user_id)` on `team_membership`
- partial unique index for active player club membership
- partial unique index for active player team membership
- partial unique index for `ClubManager` per club
- partial unique index for `ClubManager` per user if one-club-only is required
- check constraint ensuring invitation targets exactly one scope
- check constraint ensuring club invitation role is only `TeamManager`
- check constraint ensuring team invitation role is not `ClubManager`

---

## Testing Strategy

### Unit Tests

Use for:

- invitation validation
- email matching
- player constraint enforcement
- claim generation helpers
- scope authorization helpers

### Integration Tests

Use PostgreSQL-backed tests for:

- enum mappings
- membership constraints
- invitation acceptance flow
- club creation auto-membership
- token refresh and revocation behavior

### API Tests

Use full HTTP tests for:

- register/login
- create club
- invite user
- accept invitation
- forbidden cross-club/team access

### Email Tests

- integration test with mocked `IEmailService`
- optional SMTP smoke test in non-local environment

---

## File-Level Impact Summary

### New Files

Expected around `25`:

- club entities/configurations/services/controllers
- membership entities/configurations/services/controllers
- invitation entities/configurations/services/controllers
- email service
- new migrations

### Files To Delete

Expected around `14`:

- approval services/controllers/DTOs
- role lookup table related code
- obsolete migration artifacts tied to old role model

### Files To Modify

Expected around `12`:

- `Program.cs`
- `AuthService`
- `TokenService`
- `AppDbContext`
- enums
- auth DTOs
- middleware

---

## Recommended Migration Order

1. Add new enums and tables first.
2. Build new services/controllers in parallel with old ones.
3. Switch auth token generation to membership-based claims.
4. Cut API over from approval model to invitation model.
5. Remove old approval code.
6. Remove old role lookup model.
7. Run final cleanup migration.

---

## Final Summary

This redesign changes the system from:

- account approval + direct role assignment

to:

- open registration + invitation-based scoped memberships

The new model is a better fit because:

- roles are scoped to club/team context
- the same user can have different roles in different organizations
- player restrictions are explicit and enforceable
- club ownership is clear
- invitation links become the single source of role assignment

This is a real auth redesign, not a patch. It should be treated as the new baseline architecture for Equipex.
