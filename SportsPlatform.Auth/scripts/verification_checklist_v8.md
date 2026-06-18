# Equipex V8 Verification Checklist

1. Register a local user and confirm `accessToken` + `refreshToken` are returned immediately.
2. Log in with the same local user and confirm `roles`, `clubs`, and `teams` are present in the response.
3. Create a club and confirm the creator appears as `ClubManager`.
4. Try to create a second club with the same user and confirm it is rejected.
5. Create a club invitation and confirm an invitation row is created with role `TeamManager`.
6. Accept the club invitation with a matching-email user and confirm an active `club_membership` row is created.
7. Create a team under the club and confirm an active `team_membership` row is created for the creator with role `TeamManager`.
8. Create a team invitation for `Player` or `Coach` and confirm the invitation email is sent and stored.
9. Accept the team invitation and confirm an active `team_membership` row is created.
10. Try accepting an invitation from a different signed-in email and confirm it is rejected.
11. Try assigning a second active player team membership and confirm it is rejected.
12. List club teams, team members, club invitations, and team invitations and confirm the data is scoped correctly.
13. Remove a team member and confirm the membership status becomes `Revoked` and refresh tokens are revoked.
14. Delete a team and confirm the team is soft-deleted and active memberships are revoked.
15. Refresh a token and confirm the returned claims still reflect current memberships.
