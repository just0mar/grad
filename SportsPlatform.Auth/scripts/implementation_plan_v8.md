# Equipex Redesign -- Complete Implementation Plan v8

> Club-centric hierarchy with invitation-based onboarding. All major decisions finalized. This version corrects the inconsistencies from the previous draft and is the recommended execution baseline.

---

## Part 1: System Architecture

### Hierarchy

```text
Admin (User.IsAdmin - global superuser)
└── Club (Club.CreatedBy = Club Manager)
    ├── ClubMembership (TeamManager only)
    └── Team (created by ClubManager or TeamManager)
        └── TeamMembership (TeamManager, Coach, FitnessCoach, TeamAnalyst, TeamDoctor, Player)
```

### Important Scope Rules

- `Admin` is global.
- `ClubManager` is not stored in `ClubMembership`; it is derived from `Club.CreatedBy`.
- `ClubMembership` exists for club-scoped non-owner roles. In this design that means `TeamManager` only.
- `TeamMembership` exists for team-scoped roles: `TeamManager`, `Coach`, `FitnessCoach`, `TeamAnalyst`, `TeamDoctor`, `Player`.
- `ClubManager` cannot hold any team membership inside their own club.

### Invitation Flows

```text
ClubManager ──invite──▶ TeamManager ──accept──▶ ClubMembership(role=TeamManager)
ClubManager ──create──▶ Team ──invite──▶ Staff/Player ──accept──▶ TeamMembership
TeamManager ──create──▶ Team ──auto-add self as TeamManager──▶ TeamMembership
TeamManager ──invite──▶ Staff/Player/Co-Manager ──accept──▶ TeamMembership
```

### Authority Matrix

| Action | Admin | Club Manager | Team Manager |
|---|---|---|---|
| Create club | -- | ✓ (max 1) | -- |
| Delete club | ✓ | ✓ (own) | -- |
| Invite TeamManager to club | ✓ | ✓ | -- |
| Create team | ✓ | ✓ (own club) | ✓ (own club via club membership) |
| Delete team | ✓ | ✓ (any in club) | ✓ (teams they manage) |
| Invite to team | ✓ | ✓ (any in club) | ✓ (teams they manage) |
| Remove club member | ✓ | ✓ | -- |
| Remove team member | ✓ | ✓ (any in club) | ✓ (teams they manage) |

### Constraints

- one club role per user per club: `UNIQUE(club_id, user_id)`
- one team role per user per team: `UNIQUE(team_id, user_id)`
- `ClubManager` cannot have team membership in their own club
- `Player` may have at most one active `ClubMembership` or club ownership context total
- `Player` may have at most one active `TeamMembership` total
- `Player` cannot hold non-player memberships anywhere
- a user may create at most one club
- invitation email must match the accepting user email exactly

---

## Part 2: Files to Delete

These should be removed during final cleanup, not at the very start of execution.

### Entities

- `SportsPlatform.Auth.Core/Entities/UserApprovalRequest.cs`
- `SportsPlatform.Auth.Core/Entities/UserRole.cs`
- `SportsPlatform.Auth.Core/Entities/TeamManager.cs`
- `SportsPlatform.Auth.Core/Entities/Role.cs`

### Enums

- `SportsPlatform.Auth.Core/Enums/ApprovalRequestStatus.cs`
- `SportsPlatform.Auth.Core/Enums/UserRoleStatus.cs`

### EF Configurations

- `SportsPlatform.Auth.Infrastructure/Data/Configurations/UserApprovalRequestConfiguration.cs`
- `SportsPlatform.Auth.Infrastructure/Data/Configurations/UserRoleConfiguration.cs`
- `SportsPlatform.Auth.Infrastructure/Data/Configurations/TeamManagerConfiguration.cs`
- `SportsPlatform.Auth.Infrastructure/Data/Configurations/RoleConfiguration.cs`

### Services & Interfaces

- `SportsPlatform.Auth.Core/Interfaces/IApprovalService.cs`
- `SportsPlatform.Auth.Infrastructure/Services/ApprovalService.cs`

### Controllers

- `SportsPlatform.Auth.Api/Controllers/ApprovalController.cs`

### DTOs

- `SportsPlatform.Auth.Core/DTOs/Request/ApprovalDecisionRequest.cs`
- `SportsPlatform.Auth.Core/DTOs/Request/UpdateMemberRequest.cs`
- `SportsPlatform.Auth.Core/DTOs/Response/ApprovalRequestDto.cs`
- `SportsPlatform.Auth.Core/DTOs/Response/ManagerSummaryDto.cs`
- `SportsPlatform.Auth.Core/DTOs/Response/MemberProfileDto.cs`
- `SportsPlatform.Auth.Core/DTOs/Response/MemberRoleDto.cs`

### Legacy SQL migrations

Do not delete old SQL migrations until cutover is complete and the new schema is fully active.

---

## Part 3: Enums

### [MODIFY] `Core/Enums/RoleNameType.cs`

```csharp
using NpgsqlTypes;

namespace SportsPlatform.Auth.Core.Enums;

public enum RoleNameType
{
    [PgName("Admin")]        Admin,
    [PgName("ClubManager")]  ClubManager,
    [PgName("TeamManager")]  TeamManager,
    [PgName("Coach")]        Coach,
    [PgName("FitnessCoach")] FitnessCoach,
    [PgName("TeamAnalyst")]  TeamAnalyst,
    [PgName("TeamDoctor")]   TeamDoctor,
    [PgName("Player")]       Player
}
```

### [NEW] `Core/Enums/InvitationStatus.cs`

```csharp
using NpgsqlTypes;

namespace SportsPlatform.Auth.Core.Enums;

public enum InvitationStatus
{
    [PgName("Pending")]   Pending,
    [PgName("Accepted")]  Accepted,
    [PgName("Expired")]   Expired,
    [PgName("Cancelled")] Cancelled
}
```

### [NEW] `Core/Enums/MembershipStatus.cs`

```csharp
using NpgsqlTypes;

namespace SportsPlatform.Auth.Core.Enums;

public enum MembershipStatus
{
    [PgName("Active")]  Active,
    [PgName("Revoked")] Revoked,
    [PgName("Left")]    Left
}
```

---

## Part 4: Entities

### [NEW] `Core/Entities/Club.cs`

```csharp
namespace SportsPlatform.Auth.Core.Entities;

public class Club
{
    public Guid ClubId { get; set; }
    public string Name { get; set; } = string.Empty;
    public Guid CreatedBy { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public User Creator { get; set; } = null!;
    public ICollection<ClubMembership> Memberships { get; set; } = new List<ClubMembership>();
    public ICollection<Team> Teams { get; set; } = new List<Team>();
    public ICollection<Invitation> Invitations { get; set; } = new List<Invitation>();
}
```

### [NEW] `Core/Entities/ClubMembership.cs`

```csharp
using SportsPlatform.Auth.Core.Enums;

namespace SportsPlatform.Auth.Core.Entities;

public class ClubMembership
{
    public Guid ClubMembershipId { get; set; }
    public Guid ClubId { get; set; }
    public Guid UserId { get; set; }
    public RoleNameType Role { get; set; }
    public MembershipStatus Status { get; set; }
    public Guid? InvitedBy { get; set; }
    public DateTime JoinedAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public Club Club { get; set; } = null!;
    public User User { get; set; } = null!;
    public User? InvitedByUser { get; set; }
}
```

### [NEW] `Core/Entities/TeamMembership.cs`

```csharp
using SportsPlatform.Auth.Core.Enums;

namespace SportsPlatform.Auth.Core.Entities;

public class TeamMembership
{
    public Guid TeamMembershipId { get; set; }
    public Guid TeamId { get; set; }
    public Guid UserId { get; set; }
    public RoleNameType Role { get; set; }
    public MembershipStatus Status { get; set; }
    public Guid? InvitedBy { get; set; }
    public DateTime JoinedAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public Team Team { get; set; } = null!;
    public User User { get; set; } = null!;
    public User? InvitedByUser { get; set; }
}
```

### [NEW] `Core/Entities/Invitation.cs`

```csharp
using SportsPlatform.Auth.Core.Enums;

namespace SportsPlatform.Auth.Core.Entities;

public class Invitation
{
    public Guid InvitationId { get; set; }
    public string Token { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public RoleNameType Role { get; set; }
    public Guid ClubId { get; set; }
    public Guid? TeamId { get; set; }
    public Guid InvitedBy { get; set; }
    public InvitationStatus Status { get; set; }
    public DateTime ExpiresAt { get; set; }
    public DateTime? AcceptedAt { get; set; }
    public Guid? AcceptedByUserId { get; set; }
    public DateTime CreatedAt { get; set; }

    public Club Club { get; set; } = null!;
    public Team? Team { get; set; }
    public User InvitedByUser { get; set; } = null!;
    public User? AcceptedByUser { get; set; }
}
```

### [MODIFY] `Core/Entities/Team.cs`

```csharp
namespace SportsPlatform.Auth.Core.Entities;

public class Team
{
    public Guid TeamId { get; set; }
    public Guid ClubId { get; set; }
    public string TeamName { get; set; } = string.Empty;
    public Guid CategoryId { get; set; }
    public Guid CreatedBy { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public Club Club { get; set; } = null!;
    public User Creator { get; set; } = null!;
    public ICollection<TeamMembership> Memberships { get; set; } = new List<TeamMembership>();
    public ICollection<Invitation> Invitations { get; set; } = new List<Invitation>();
}
```

### [MODIFY] `Core/Entities/User.cs`

```csharp
namespace SportsPlatform.Auth.Core.Entities;

public class User
{
    public Guid UserId { get; set; }
    public string Email { get; set; } = string.Empty;
    public string? Username { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? PhoneNumber { get; set; }
    public DateOnly? Dob { get; set; }
    public bool IsAdmin { get; set; }
    public DateTime? DeletedAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public ICollection<UserAuthProvider> AuthProviders { get; set; } = new List<UserAuthProvider>();
    public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();
    public Club? CreatedClub { get; set; }
    public ICollection<ClubMembership> ClubMemberships { get; set; } = new List<ClubMembership>();
    public ICollection<TeamMembership> TeamMemberships { get; set; } = new List<TeamMembership>();
}
```

---

## Part 5: EF Configurations

### [NEW] `Infrastructure/Data/Configurations/ClubConfiguration.cs`

```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SportsPlatform.Auth.Core.Entities;

namespace SportsPlatform.Auth.Infrastructure.Data.Configurations;

public class ClubConfiguration : IEntityTypeConfiguration<Club>
{
    public void Configure(EntityTypeBuilder<Club> builder)
    {
        builder.ToTable("club");
        builder.HasKey(c => c.ClubId);
        builder.Property(c => c.ClubId).HasColumnName("club_id");
        builder.Property(c => c.Name).HasColumnName("name").HasMaxLength(200).IsRequired();
        builder.Property(c => c.CreatedBy).HasColumnName("created_by");
        builder.Property(c => c.DeletedAt).HasColumnName("deleted_at");
        builder.Property(c => c.CreatedAt).HasColumnName("created_at");
        builder.Property(c => c.UpdatedAt).HasColumnName("updated_at");

        builder.HasIndex(c => c.CreatedBy).IsUnique();

        builder.HasOne(c => c.Creator)
               .WithOne(u => u.CreatedClub)
               .HasForeignKey<Club>(c => c.CreatedBy)
               .OnDelete(DeleteBehavior.Restrict);

        builder.HasQueryFilter(c => c.DeletedAt == null);
    }
}
```

### [NEW] `Infrastructure/Data/Configurations/ClubMembershipConfiguration.cs`

```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SportsPlatform.Auth.Core.Entities;

namespace SportsPlatform.Auth.Infrastructure.Data.Configurations;

public class ClubMembershipConfiguration : IEntityTypeConfiguration<ClubMembership>
{
    public void Configure(EntityTypeBuilder<ClubMembership> builder)
    {
        builder.ToTable("club_membership");
        builder.HasKey(cm => cm.ClubMembershipId);
        builder.Property(cm => cm.ClubMembershipId).HasColumnName("club_membership_id");
        builder.Property(cm => cm.ClubId).HasColumnName("club_id");
        builder.Property(cm => cm.UserId).HasColumnName("user_id");
        builder.Property(cm => cm.Role).HasColumnName("role").HasColumnType("role_name_type");
        builder.Property(cm => cm.Status).HasColumnName("status").HasColumnType("membership_status");
        builder.Property(cm => cm.InvitedBy).HasColumnName("invited_by");
        builder.Property(cm => cm.JoinedAt).HasColumnName("joined_at");
        builder.Property(cm => cm.CreatedAt).HasColumnName("created_at");
        builder.Property(cm => cm.UpdatedAt).HasColumnName("updated_at");

        builder.HasIndex(cm => new { cm.ClubId, cm.UserId }).IsUnique();
        builder.HasIndex(cm => cm.UserId);

        builder.HasOne(cm => cm.Club)
               .WithMany(c => c.Memberships)
               .HasForeignKey(cm => cm.ClubId)
               .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(cm => cm.User)
               .WithMany(u => u.ClubMemberships)
               .HasForeignKey(cm => cm.UserId)
               .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(cm => cm.InvitedByUser)
               .WithMany()
               .HasForeignKey(cm => cm.InvitedBy)
               .OnDelete(DeleteBehavior.SetNull);
    }
}
```

### [NEW] `Infrastructure/Data/Configurations/TeamMembershipConfiguration.cs`

```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SportsPlatform.Auth.Core.Entities;

namespace SportsPlatform.Auth.Infrastructure.Data.Configurations;

public class TeamMembershipConfiguration : IEntityTypeConfiguration<TeamMembership>
{
    public void Configure(EntityTypeBuilder<TeamMembership> builder)
    {
        builder.ToTable("team_membership");
        builder.HasKey(tm => tm.TeamMembershipId);
        builder.Property(tm => tm.TeamMembershipId).HasColumnName("team_membership_id");
        builder.Property(tm => tm.TeamId).HasColumnName("team_id");
        builder.Property(tm => tm.UserId).HasColumnName("user_id");
        builder.Property(tm => tm.Role).HasColumnName("role").HasColumnType("role_name_type");
        builder.Property(tm => tm.Status).HasColumnName("status").HasColumnType("membership_status");
        builder.Property(tm => tm.InvitedBy).HasColumnName("invited_by");
        builder.Property(tm => tm.JoinedAt).HasColumnName("joined_at");
        builder.Property(tm => tm.CreatedAt).HasColumnName("created_at");
        builder.Property(tm => tm.UpdatedAt).HasColumnName("updated_at");

        builder.HasIndex(tm => new { tm.TeamId, tm.UserId }).IsUnique();
        builder.HasIndex(tm => tm.UserId);

        builder.HasOne(tm => tm.Team)
               .WithMany(t => t.Memberships)
               .HasForeignKey(tm => tm.TeamId)
               .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(tm => tm.User)
               .WithMany(u => u.TeamMemberships)
               .HasForeignKey(tm => tm.UserId)
               .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(tm => tm.InvitedByUser)
               .WithMany()
               .HasForeignKey(tm => tm.InvitedBy)
               .OnDelete(DeleteBehavior.SetNull);
    }
}
```

### [NEW] `Infrastructure/Data/Configurations/InvitationConfiguration.cs`

```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SportsPlatform.Auth.Core.Entities;

namespace SportsPlatform.Auth.Infrastructure.Data.Configurations;

public class InvitationConfiguration : IEntityTypeConfiguration<Invitation>
{
    public void Configure(EntityTypeBuilder<Invitation> builder)
    {
        builder.ToTable("invitation");
        builder.HasKey(i => i.InvitationId);
        builder.Property(i => i.InvitationId).HasColumnName("invitation_id");
        builder.Property(i => i.Token).HasColumnName("token").HasMaxLength(128).IsRequired();
        builder.Property(i => i.Email).HasColumnName("email").HasMaxLength(320).IsRequired();
        builder.Property(i => i.Role).HasColumnName("role").HasColumnType("role_name_type");
        builder.Property(i => i.ClubId).HasColumnName("club_id");
        builder.Property(i => i.TeamId).HasColumnName("team_id");
        builder.Property(i => i.InvitedBy).HasColumnName("invited_by");
        builder.Property(i => i.Status).HasColumnName("status").HasColumnType("invitation_status");
        builder.Property(i => i.ExpiresAt).HasColumnName("expires_at");
        builder.Property(i => i.AcceptedAt).HasColumnName("accepted_at");
        builder.Property(i => i.AcceptedByUserId).HasColumnName("accepted_by_user_id");
        builder.Property(i => i.CreatedAt).HasColumnName("created_at");

        builder.HasIndex(i => i.Token).IsUnique();
        builder.HasIndex(i => i.Email);
        builder.HasIndex(i => i.ClubId);
        builder.HasIndex(i => i.TeamId);

        builder.HasOne(i => i.Club)
               .WithMany(c => c.Invitations)
               .HasForeignKey(i => i.ClubId)
               .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(i => i.Team)
               .WithMany(t => t.Invitations)
               .HasForeignKey(i => i.TeamId)
               .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(i => i.InvitedByUser)
               .WithMany()
               .HasForeignKey(i => i.InvitedBy)
               .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(i => i.AcceptedByUser)
               .WithMany()
               .HasForeignKey(i => i.AcceptedByUserId)
               .OnDelete(DeleteBehavior.SetNull);
    }
}
```

### [MODIFY] `Infrastructure/Data/Configurations/TeamConfiguration.cs`

```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SportsPlatform.Auth.Core.Entities;

namespace SportsPlatform.Auth.Infrastructure.Data.Configurations;

public class TeamConfiguration : IEntityTypeConfiguration<Team>
{
    public void Configure(EntityTypeBuilder<Team> builder)
    {
        builder.ToTable("team");
        builder.HasKey(t => t.TeamId);
        builder.Property(t => t.TeamId).HasColumnName("team_id");
        builder.Property(t => t.ClubId).HasColumnName("club_id");
        builder.Property(t => t.TeamName).HasColumnName("team_name").HasMaxLength(100);
        builder.Property(t => t.CategoryId).HasColumnName("category_id");
        builder.Property(t => t.CreatedBy).HasColumnName("created_by");
        builder.Property(t => t.DeletedAt).HasColumnName("deleted_at");
        builder.Property(t => t.CreatedAt).HasColumnName("created_at");
        builder.Property(t => t.UpdatedAt).HasColumnName("updated_at");

        builder.HasIndex(t => t.ClubId);

        builder.HasOne(t => t.Club)
               .WithMany(c => c.Teams)
               .HasForeignKey(t => t.ClubId)
               .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(t => t.Creator)
               .WithMany()
               .HasForeignKey(t => t.CreatedBy)
               .OnDelete(DeleteBehavior.Restrict);

        builder.HasQueryFilter(t => t.DeletedAt == null);
    }
}
```

### [MODIFY] `Infrastructure/Data/Configurations/UserConfiguration.cs`

```csharp
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SportsPlatform.Auth.Core.Entities;

namespace SportsPlatform.Auth.Infrastructure.Data.Configurations;

public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("users");
        builder.HasKey(u => u.UserId);
        builder.Property(u => u.UserId).HasColumnName("user_id");
        builder.Property(u => u.Email).HasColumnName("email").HasColumnType("citext").IsRequired();
        builder.Property(u => u.Username).HasColumnName("username").HasColumnType("citext");
        builder.Property(u => u.Name).HasColumnName("name").HasMaxLength(200).IsRequired();
        builder.Property(u => u.PhoneNumber).HasColumnName("phone_number").HasMaxLength(30);
        builder.Property(u => u.Dob).HasColumnName("dob");
        builder.Property(u => u.IsAdmin).HasColumnName("is_admin").HasDefaultValue(false);
        builder.Property(u => u.DeletedAt).HasColumnName("deleted_at");
        builder.Property(u => u.CreatedAt).HasColumnName("created_at");
        builder.Property(u => u.UpdatedAt).HasColumnName("updated_at");

        builder.HasMany(u => u.AuthProviders)
               .WithOne(a => a.User)
               .HasForeignKey(a => a.UserId);

        builder.HasMany(u => u.RefreshTokens)
               .WithOne(rt => rt.User)
               .HasForeignKey(rt => rt.UserId);

        builder.HasMany(u => u.ClubMemberships)
               .WithOne(cm => cm.User)
               .HasForeignKey(cm => cm.UserId);

        builder.HasMany(u => u.TeamMemberships)
               .WithOne(tm => tm.User)
               .HasForeignKey(tm => tm.UserId);

        builder.HasQueryFilter(u => u.DeletedAt == null);
    }
}
```

---

## Part 6: AppDbContext

### [MODIFY] `Infrastructure/Data/AppDbContext.cs`

```csharp
using Microsoft.EntityFrameworkCore;
using SportsPlatform.Auth.Core.Entities;
using SportsPlatform.Auth.Core.Enums;
using SportsPlatform.Auth.Infrastructure.Data.Configurations;

namespace SportsPlatform.Auth.Infrastructure.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<UserAuthProvider> UserAuthProviders => Set<UserAuthProvider>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<Club> Clubs => Set<Club>();
    public DbSet<ClubMembership> ClubMemberships => Set<ClubMembership>();
    public DbSet<Team> Teams => Set<Team>();
    public DbSet<TeamMembership> TeamMemberships => Set<TeamMembership>();
    public DbSet<Invitation> Invitations => Set<Invitation>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.HasPostgresEnum<AuthProviderType>("public", "auth_provider_type");
        modelBuilder.HasPostgresEnum<RoleNameType>("public", "role_name_type");
        modelBuilder.HasPostgresEnum<InvitationStatus>("public", "invitation_status");
        modelBuilder.HasPostgresEnum<MembershipStatus>("public", "membership_status");

        modelBuilder.ApplyConfiguration(new UserConfiguration());
        modelBuilder.ApplyConfiguration(new UserAuthProviderConfiguration());
        modelBuilder.ApplyConfiguration(new RefreshTokenConfiguration());
        modelBuilder.ApplyConfiguration(new ClubConfiguration());
        modelBuilder.ApplyConfiguration(new ClubMembershipConfiguration());
        modelBuilder.ApplyConfiguration(new TeamConfiguration());
        modelBuilder.ApplyConfiguration(new TeamMembershipConfiguration());
        modelBuilder.ApplyConfiguration(new InvitationConfiguration());
    }
}
```

---

## Part 7: DTOs

### New Request DTOs

**`Core/DTOs/Request/CreateClubRequest.cs`**

```csharp
using System.ComponentModel.DataAnnotations;

namespace SportsPlatform.Auth.Core.DTOs.Request;

public class CreateClubRequest
{
    [Required, MaxLength(200)]
    public string Name { get; set; } = string.Empty;
}
```

**`Core/DTOs/Request/CreateInvitationRequest.cs`**

```csharp
using System.ComponentModel.DataAnnotations;
using SportsPlatform.Auth.Core.Enums;

namespace SportsPlatform.Auth.Core.DTOs.Request;

public class CreateInvitationRequest
{
    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    public RoleNameType RoleName { get; set; }
}
```

### New Response DTOs

**`Core/DTOs/Response/ClubDto.cs`**

```csharp
namespace SportsPlatform.Auth.Core.DTOs.Response;

public class ClubDto
{
    public Guid ClubId { get; set; }
    public string Name { get; set; } = string.Empty;
    public Guid ManagerUserId { get; set; }
    public string ManagerName { get; set; } = string.Empty;
    public int MemberCount { get; set; }
    public int TeamCount { get; set; }
    public DateTime CreatedAt { get; set; }
}
```

**`Core/DTOs/Response/ClubSummaryDto.cs`**

```csharp
namespace SportsPlatform.Auth.Core.DTOs.Response;

public class ClubSummaryDto
{
    public Guid ClubId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string MyRole { get; set; } = string.Empty;
}
```

**`Core/DTOs/Response/ClubMemberDto.cs`**

```csharp
namespace SportsPlatform.Auth.Core.DTOs.Response;

public class ClubMemberDto
{
    public Guid UserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
    public DateTime JoinedAt { get; set; }
}
```

**`Core/DTOs/Response/InvitationDto.cs`**

```csharp
namespace SportsPlatform.Auth.Core.DTOs.Response;

public class InvitationDto
{
    public Guid InvitationId { get; set; }
    public string Email { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
    public string ClubName { get; set; } = string.Empty;
    public string? TeamName { get; set; }
    public string InviterName { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public DateTime CreatedAt { get; set; }
}
```

**`Core/DTOs/Response/InvitationAcceptResultDto.cs`**

```csharp
namespace SportsPlatform.Auth.Core.DTOs.Response;

public class InvitationAcceptResultDto
{
    public string Message { get; set; } = string.Empty;
    public Guid ClubId { get; set; }
    public Guid? TeamId { get; set; }
    public string Role { get; set; } = string.Empty;
    public string ClubName { get; set; } = string.Empty;
    public string? TeamName { get; set; }
}
```

### Modified Response DTOs

**`Core/DTOs/Response/TeamDto.cs`**

```csharp
namespace SportsPlatform.Auth.Core.DTOs.Response;

public class TeamDto
{
    public Guid TeamId { get; set; }
    public Guid ClubId { get; set; }
    public string TeamName { get; set; } = string.Empty;
    public Guid CategoryId { get; set; }
    public Guid CreatedBy { get; set; }
    public string CreatorName { get; set; } = string.Empty;
    public int MemberCount { get; set; }
    public DateTime CreatedAt { get; set; }
}
```

**`Core/DTOs/Response/TeamMemberDto.cs`**

```csharp
namespace SportsPlatform.Auth.Core.DTOs.Response;

public class TeamMemberDto
{
    public Guid UserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? PhoneNumber { get; set; }
    public string Role { get; set; } = string.Empty;
    public DateTime JoinedAt { get; set; }
}
```

**`Core/DTOs/Response/AuthResponse.cs`**

```csharp
namespace SportsPlatform.Auth.Core.DTOs.Response;

public class AuthResponse
{
    public string Message { get; set; } = string.Empty;
    public string? AccessToken { get; set; }
    public string? RefreshToken { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public bool RequiresProfileCompletion { get; set; }
    public UserInfoDto? User { get; set; }
}

public class UserInfoDto
{
    public Guid UserId { get; set; }
    public string Email { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public bool IsAdmin { get; set; }
    public List<string> Roles { get; set; } = new();
    public List<UserClubInfoDto> Clubs { get; set; } = new();
    public List<UserTeamInfoDto> Teams { get; set; } = new();
}

public class UserClubInfoDto
{
    public Guid ClubId { get; set; }
    public string ClubName { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
}

public class UserTeamInfoDto
{
    public Guid TeamId { get; set; }
    public string TeamName { get; set; } = string.Empty;
    public Guid ClubId { get; set; }
    public string Role { get; set; } = string.Empty;
}
```

---

## Part 8: Service Interfaces

### [NEW] `Core/Interfaces/IClubService.cs`

```csharp
using SportsPlatform.Auth.Core.DTOs.Request;
using SportsPlatform.Auth.Core.DTOs.Response;

namespace SportsPlatform.Auth.Core.Interfaces;

public interface IClubService
{
    Task<ClubDto> CreateClubAsync(Guid userId, CreateClubRequest request);
    Task<ClubDto> GetClubAsync(Guid clubId, Guid callerUserId);
    Task<List<ClubSummaryDto>> GetMyClubsAsync(Guid userId);
    Task DeleteClubAsync(Guid clubId, Guid callerUserId);
    Task<List<ClubMemberDto>> GetClubMembersAsync(Guid clubId, Guid callerUserId);
    Task RemoveClubMemberAsync(Guid clubId, Guid targetUserId, Guid callerUserId);
}
```

### [NEW] `Core/Interfaces/IInvitationService.cs`

```csharp
using SportsPlatform.Auth.Core.DTOs.Request;
using SportsPlatform.Auth.Core.DTOs.Response;

namespace SportsPlatform.Auth.Core.Interfaces;

public interface IInvitationService
{
    Task<InvitationDto> CreateClubInvitationAsync(Guid clubId, CreateInvitationRequest request, Guid invitedBy);
    Task<InvitationDto> CreateTeamInvitationAsync(Guid clubId, Guid teamId, CreateInvitationRequest request, Guid invitedBy);
    Task<InvitationDto> GetInvitationAsync(string token);
    Task<InvitationAcceptResultDto> AcceptInvitationAsync(string token, Guid acceptingUserId);
    Task<List<InvitationDto>> GetClubInvitationsAsync(Guid clubId, Guid callerUserId);
    Task<List<InvitationDto>> GetTeamInvitationsAsync(Guid clubId, Guid teamId, Guid callerUserId);
    Task CancelInvitationAsync(Guid invitationId, Guid callerUserId);
}
```

### [NEW] `Core/Interfaces/IEmailService.cs`

```csharp
namespace SportsPlatform.Auth.Core.Interfaces;

public interface IEmailService
{
    Task SendInvitationEmailAsync(
        string recipientEmail,
        string invitationToken,
        string clubOrTeamName,
        string roleName,
        string inviterName);
}
```

### [MODIFY] `Core/Interfaces/ITeamService.cs`

```csharp
using SportsPlatform.Auth.Core.DTOs.Request;
using SportsPlatform.Auth.Core.DTOs.Response;

namespace SportsPlatform.Auth.Core.Interfaces;

public interface ITeamService
{
    Task<List<TeamCategoryDto>> GetTeamCategoriesAsync();
    Task<TeamDto> CreateTeamAsync(Guid clubId, Guid callerUserId, CreateTeamRequest request);
    Task<List<TeamDto>> GetClubTeamsAsync(Guid clubId, Guid callerUserId);
    Task<TeamDto> GetTeamAsync(Guid clubId, Guid teamId, Guid callerUserId);
    Task DeleteTeamAsync(Guid clubId, Guid teamId, Guid callerUserId);
    Task<List<TeamMemberDto>> GetTeamMembersAsync(Guid clubId, Guid teamId, Guid callerUserId);
    Task RemoveTeamMemberAsync(Guid clubId, Guid teamId, Guid targetUserId, Guid callerUserId);
}
```

---

## Part 9: Service Implementations (Key Logic)

### [NEW] `Infrastructure/Services/ClubService.cs`

Key rules:

- `CreateClubAsync`
  - reject if user already created a club
  - create club
  - do not create `ClubMembership` for owner
  - owner is recognized through `Club.CreatedBy`
- `GetMyClubsAsync`
  - include created club as `ClubManager`
  - include `ClubMembership` rows as `TeamManager`
- `RemoveClubMemberAsync`
  - only ClubManager/Admin
  - mark `ClubMembership.Status = Revoked`
  - mark all team memberships in that club for that user as `Revoked`
  - revoke user refresh tokens

### [NEW] `Infrastructure/Services/InvitationService.cs`

**`CreateClubInvitationAsync`**

1. Validate caller is club owner or admin
2. Validate `request.RoleName == TeamManager`
3. Create invitation with:
   - `ClubId = clubId`
   - `TeamId = null`
   - `ExpiresAt = UtcNow + 7 days`
4. Send email

**`CreateTeamInvitationAsync`**

1. Load team, validate `team.ClubId == clubId`
2. Validate caller is:
   - club owner, or
   - active `TeamManager` of this team
3. Validate role is one of:
   - `TeamManager`
   - `Coach`
   - `FitnessCoach`
   - `TeamAnalyst`
   - `TeamDoctor`
   - `Player`
4. Create invitation with:
   - `ClubId = clubId`
   - `TeamId = teamId`
5. Send email

**`AcceptInvitationAsync`**

1. Find invitation by token
2. Validate:
   - `Status == Pending`
   - not expired
3. Load accepting user
4. Validate exact email match
5. If `TeamId == null`:
   - create `ClubMembership(role=TeamManager, status=Active)`
6. If `TeamId != null`:
   - load team and club
   - reject if accepting user is club owner
   - validate no duplicate active team membership for same team
   - enforce player uniqueness
   - create `TeamMembership(status=Active)`
7. Mark invitation as accepted
8. revoke user refresh tokens

### [NEW] `Infrastructure/Services/EmailService.cs`

Use MailKit and Gmail SMTP with config-based credentials.

### [MODIFY] `Infrastructure/Services/AuthService.cs`

Changes:

- remove all approval logic
- registration returns immediate success
- Google OAuth no longer creates approval rows
- login loads:
  - `IsAdmin`
  - created club
  - active club memberships
  - active team memberships

### [MODIFY] `Infrastructure/Services/TokenService.cs`

JWT claims:

- flat `Admin`
- flat `ClubManager` if user owns a club
- scoped claims:
  - `club:{clubId}=TeamManager`
  - `team:{teamId}=TeamManager|Coach|FitnessCoach|TeamAnalyst|TeamDoctor|Player`
- `is_admin=true|false`

### [MODIFY] `Infrastructure/Services/TeamService.cs`

Key changes:

- all methods take `clubId`
- `CreateTeamAsync`
  - allowed for ClubManager or active club `TeamManager`
  - creates team under club
  - auto-add creator as active `TeamMembership(role=TeamManager)`
- authorization checks:
  - club owner can manage any team in club
  - team manager can manage only teams where they have active `TeamMembership(role=TeamManager)`

---

## Part 10: Controllers

### [NEW] `Api/Controllers/ClubController.cs`

Route: `[Route("clubs")]`

- `POST /clubs`
- `GET /clubs/my`
- `GET /clubs/{clubId}`
- `DELETE /clubs/{clubId}`
- `GET /clubs/{clubId}/members`
- `DELETE /clubs/{clubId}/members/{userId}`
- `POST /clubs/{clubId}/invitations`
- `GET /clubs/{clubId}/invitations`
- `DELETE /clubs/{clubId}/invitations/{invId}`

### [NEW] `Api/Controllers/InvitationController.cs`

Route: `[Route("invitations")]`

- `GET /invitations/{token}`
- `POST /invitations/{token}/accept`

### [MODIFY] `Api/Controllers/TeamController.cs`

Route: `[Route("clubs/{clubId:guid}/teams")]`

- `POST /clubs/{clubId}/teams`
- `GET /clubs/{clubId}/teams`
- `GET /clubs/{clubId}/teams/{teamId}`
- `DELETE /clubs/{clubId}/teams/{teamId}`
- `GET /clubs/{clubId}/teams/{teamId}/members`
- `DELETE /clubs/{clubId}/teams/{teamId}/members/{userId}`
- `POST /clubs/{clubId}/teams/{teamId}/invitations`
- `GET /clubs/{clubId}/teams/{teamId}/invitations`

### [MODIFY] `Api/Controllers/AuthController.cs`

- remove all approval-related wording and redirect flags
- keep Google OAuth support

---

## Part 11: Middleware & Program.cs

### [MODIFY] `Api/Middleware/RlsMiddleware.cs`

```csharp
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using SportsPlatform.Auth.Infrastructure.Data;

namespace SportsPlatform.Auth.Api.Middleware;

public class RlsMiddleware
{
    private readonly RequestDelegate _next;

    public RlsMiddleware(RequestDelegate next) { _next = next; }

    public async Task InvokeAsync(HttpContext context, AppDbContext db)
    {
        var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? string.Empty;
        var isAdmin = context.User.HasClaim("is_admin", "true") ? "true" : "false";

        await db.Database.OpenConnectionAsync();
        try
        {
            await db.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT set_config('app.user_id', {userId}, false)");
            await db.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT set_config('app.is_admin', {isAdmin}, false)");

            await _next(context);
        }
        finally
        {
            try
            {
                await db.Database.ExecuteSqlRawAsync("RESET app.user_id; RESET app.is_admin;");
            }
            catch
            {
            }

            await db.Database.CloseConnectionAsync();
        }
    }
}
```

### [MODIFY] `Api/Program.cs`

Key changes:

- remove approval-related enum mappings
- add `InvitationStatus` and `MembershipStatus`
- remove approval DI
- add:
  - `IClubService`
  - `IInvitationService`
  - `IEmailService`

### [MODIFY] `Api/appsettings.json`

Add:

```json
"Email": {
  "SmtpHost": "smtp.gmail.com",
  "SmtpPort": 587,
  "SenderEmail": "your-equipex@gmail.com",
  "SenderName": "Equipex",
  "Password": "your-16-char-app-password"
}
```

### [MODIFY] `Infrastructure/SportsPlatform.Auth.Infrastructure.csproj`

Add:

```xml
<PackageReference Include="MailKit" Version="4.12.0" />
```

---

## Part 12: SQL Migrations

### [NEW] `scripts/migrations/001_rls_functions.sql`

```sql
CREATE OR REPLACE FUNCTION current_app_user_id() RETURNS uuid AS $$
  SELECT NULLIF(current_setting('app.user_id', true), '')::uuid;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION is_admin() RETURNS boolean AS $$
  SELECT current_setting('app.is_admin', true) = 'true';
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION is_club_manager(p_club_id uuid) RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM club
    WHERE club_id = p_club_id
      AND created_by = current_app_user_id()
      AND deleted_at IS NULL
  );
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION is_club_member(p_club_id uuid) RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM club_membership
    WHERE club_id = p_club_id
      AND user_id = current_app_user_id()
      AND status = 'Active'
  );
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION is_team_member(p_team_id uuid) RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM team_membership
    WHERE team_id = p_team_id
      AND user_id = current_app_user_id()
      AND status = 'Active'
  );
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION is_team_manager(p_team_id uuid) RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM team_membership
    WHERE team_id = p_team_id
      AND user_id = current_app_user_id()
      AND role = 'TeamManager'
      AND status = 'Active'
  );
$$ LANGUAGE sql STABLE;
```

### Additional SQL required

- partial unique index for active player team membership
- partial unique index for active player club membership / ownership constraint
- check: `ClubManager` forbidden in `team_membership`
- check: `club_membership.role = TeamManager`
- check: invitation with `TeamId IS NULL` must be `TeamManager`

---

## Part 13: Execution Order

### Phase 1: Add new schema alongside old

1. Add new enums
2. Add new entities
3. Add new configurations
4. Update `AppDbContext`
5. Add SQL helper migration

### Phase 2: Add new services and API in parallel

6. Add DTOs
7. Add interfaces
8. Add `EmailService`
9. Add `ClubService`
10. Add `InvitationService`
11. Update `TeamService`
12. Update `AuthService`
13. Update `TokenService`
14. Add/modify controllers
15. Update middleware and `Program.cs`

### Phase 3: Cut auth over

16. Switch login/registration/Google flows to new membership model
17. Verify invitation acceptance and JWT claims
18. Verify club/team authorization

### Phase 4: Cleanup old system

19. Remove approval services/controllers/entities
20. Remove role lookup usage
21. Remove obsolete migrations only after cutover is stable

### Local-only reset option

If you are intentionally resetting local development DB:

22. `dotnet ef migrations add InitialCreate_v2`
23. `dotnet ef database drop --force`
24. `dotnet ef database update`
25. seed admin manually

Do not treat DB drop as a normal production migration step.

---

## Part 14: Verification Plan

| # | Test | Expected Result |
|---|---|---|
| 1 | Register -> login | Immediate access, no approval state |
| 2 | Create club | User becomes Club Manager via `Club.CreatedBy` |
| 3 | Create 2nd club | Rejected |
| 4 | Club Manager invites TeamManager | Invitation created, email sent |
| 5 | User accepts club invitation | Active `ClubMembership(role=TeamManager)` created |
| 6 | TeamManager creates team | Team created under club and active `TeamMembership(role=TeamManager)` auto-created |
| 7 | TeamManager invites Coach | Invitation created |
| 8 | User accepts team invitation | Active `TeamMembership` created |
| 9 | Club Manager invites Player to team | Works |
| 10 | Invite Player to 2nd team | Rejected |
| 11 | Invite same user to same team again | Rejected |
| 12 | Club Manager tries to join own team | Rejected |
| 13 | Forward invitation to different email | Rejected |
| 14 | Remove club member | Memberships revoked, refresh tokens revoked |
| 15 | Decode JWT | Scoped claims for clubs/teams are present |

---

## Summary of Key Corrections from Previous Draft

- added `MembershipStatus` and `Status` fields to memberships
- kept `category_id` on `team`
- kept `ClubId` on all invitations, including team invitations
- made `TeamManager` allowed in team invitations and team memberships
- filtered RLS checks by `status = 'Active'`
- removed destructive DB reset from the normal migration path
- clarified that `ClubManager` is derived from club ownership, not membership

This v8 plan is the corrected execution baseline.
