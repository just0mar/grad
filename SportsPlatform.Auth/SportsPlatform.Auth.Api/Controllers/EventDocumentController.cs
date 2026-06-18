using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SportsPlatform.Auth.Core.Entities;
using SportsPlatform.Auth.Core.Enums;
using SportsPlatform.Auth.Infrastructure.Data;

namespace SportsPlatform.Auth.Api.Controllers;

[ApiController]
[Authorize]
public class EventDocumentController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IWebHostEnvironment _env;

    public EventDocumentController(AppDbContext db, IWebHostEnvironment env)
    {
        _db = db;
        _env = env;
    }

    [HttpGet("clubs/{clubId:guid}/teams/{teamId:guid}/events/{eventId:guid}/documents")]
    public async Task<IActionResult> GetEventDocuments(Guid clubId, Guid teamId, Guid eventId)
    {
        var userId = GetCallerUserId();
        if (userId == null) return Unauthorized(new { error = "Invalid token." });
        if (!await CanViewTeamAsync(clubId, teamId, userId.Value))
            return Forbid();

        var docs = await _db.EventDocuments
            .Where(d => d.EventId == eventId)
            .OrderByDescending(d => d.CreatedAt)
            .Select(d => new
            {
                d.DocumentId,
                d.EventId,
                d.OriginalFileName,
                d.ContentType,
                d.FileSize,
                d.Description,
                UploadedBy = d.UploadedByUser.Name,
                UploadedByRole = d.UploadedByRole,
                d.CreatedAt,
            })
            .ToListAsync();

        return Ok(docs);
    }

    [HttpPost("clubs/{clubId:guid}/teams/{teamId:guid}/events/{eventId:guid}/documents")]
    public async Task<IActionResult> UploadEventDocument(Guid clubId, Guid teamId, Guid eventId, [FromForm] IFormFile? file, [FromForm] string? description)
    {
        var userId = GetCallerUserId();
        if (userId == null) return Unauthorized(new { error = "Invalid token." });
        if (file == null || file.Length == 0) return BadRequest(new { error = "A file is required." });
        var role = await GetTeamRoleAsync(teamId, userId.Value);
        if (!IsTeamStaff(role) && !await IsClubManagerAsync(clubId, userId.Value))
            return Forbid();

        var uploadsDir = Path.Combine(_env.WebRootPath, "uploads", "events", eventId.ToString());
        Directory.CreateDirectory(uploadsDir);

        var storedName = $"{Guid.NewGuid()}{Path.GetExtension(file.FileName)}";
        var storagePath = Path.Combine(uploadsDir, storedName);

        await using (var stream = new FileStream(storagePath, FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }

        var doc = new EventDocument
        {
            DocumentId = Guid.NewGuid(),
            EventId = eventId,
            UploadedByUserId = userId.Value,
            FileName = storedName,
            OriginalFileName = file.FileName,
            ContentType = file.ContentType,
            Description = description?.Trim(),
            UploadedByRole = role?.ToString() ?? "ClubManager",
            FileSize = file.Length,
            StoragePath = storagePath,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        };
        _db.EventDocuments.Add(doc);
        await _db.SaveChangesAsync();
        var uploaderName = await _db.Users
            .Where(u => u.UserId == userId.Value)
            .Select(u => u.Name)
            .FirstOrDefaultAsync();

        return Ok(new
        {
            doc.DocumentId,
            doc.EventId,
            doc.OriginalFileName,
            doc.ContentType,
            doc.FileSize,
            doc.Description,
            UploadedBy = uploaderName,
            doc.UploadedByRole,
            doc.CreatedAt,
        });
    }

    [HttpGet("events/documents/{documentId:guid}/download")]
    public async Task<IActionResult> DownloadEventDocument(Guid documentId)
    {
        var userId = GetCallerUserId();
        if (userId == null) return Unauthorized(new { error = "Invalid token." });

        var doc = await _db.EventDocuments
            .Include(d => d.Event)
                .ThenInclude(e => e.Team)
            .FirstOrDefaultAsync(d => d.DocumentId == documentId);
        if (doc == null) return NotFound(new { error = "Document not found." });
        if (!await CanViewTeamAsync(doc.Event.Team.ClubId, doc.Event.TeamId, userId.Value))
            return Forbid();

        if (!System.IO.File.Exists(doc.StoragePath))
            return NotFound(new { error = "File not found on server." });

        return PhysicalFile(doc.StoragePath, doc.ContentType, doc.OriginalFileName);
    }

    [HttpDelete("clubs/{clubId:guid}/teams/{teamId:guid}/events/{eventId:guid}/documents/{documentId:guid}")]
    public async Task<IActionResult> DeleteEventDocument(Guid clubId, Guid teamId, Guid eventId, Guid documentId)
    {
        var userId = GetCallerUserId();
        if (userId == null) return Unauthorized(new { error = "Invalid token." });
        var role = await GetTeamRoleAsync(teamId, userId.Value);
        if (!IsTeamStaff(role) && !await IsClubManagerAsync(clubId, userId.Value))
            return Forbid();

        var doc = await _db.EventDocuments.FirstOrDefaultAsync(d => d.DocumentId == documentId && d.EventId == eventId);
        if (doc == null) return NotFound(new { error = "Document not found." });

        doc.DeletedAt = DateTime.UtcNow;
        doc.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new { message = "Document deleted." });
    }

    private Guid? GetCallerUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(userIdClaim, out var parsed) ? parsed : null;
    }

    private async Task<RoleNameType?> GetTeamRoleAsync(Guid teamId, Guid userId)
    {
        return await _db.TeamMemberships
            .Where(tm => tm.TeamId == teamId && tm.UserId == userId && tm.Status == MembershipStatus.Active)
            .Select(tm => (RoleNameType?)tm.Role)
            .FirstOrDefaultAsync();
    }

    private async Task<bool> CanViewTeamAsync(Guid? clubId, Guid teamId, Guid userId)
    {
        if (await _db.Users.AnyAsync(u => u.UserId == userId && u.IsAdmin)) return true;
        if (await _db.TeamMemberships.AnyAsync(tm =>
                tm.TeamId == teamId && tm.UserId == userId && tm.Status == MembershipStatus.Active))
            return true;
        return clubId.HasValue && await _db.ClubMemberships.AnyAsync(cm =>
            cm.ClubId == clubId.Value && cm.UserId == userId && cm.Status == MembershipStatus.Active);
    }

    private Task<bool> IsClubManagerAsync(Guid clubId, Guid userId) =>
        _db.ClubMemberships.AnyAsync(cm =>
            cm.ClubId == clubId && cm.UserId == userId &&
            cm.Role == RoleNameType.ClubManager && cm.Status == MembershipStatus.Active);

    private static bool IsTeamStaff(RoleNameType? role) =>
        role is RoleNameType.Coach or RoleNameType.TeamManager or RoleNameType.TeamAnalyst
            or RoleNameType.TeamDoctor or RoleNameType.FitnessCoach;
}
