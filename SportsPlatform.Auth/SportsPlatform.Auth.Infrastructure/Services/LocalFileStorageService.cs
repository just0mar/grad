using SportsPlatform.Auth.Core.Interfaces;

namespace SportsPlatform.Auth.Infrastructure.Services;

public class LocalFileStorageService : IFileStorageService
{
    private readonly string _uploadsRoot;

    public LocalFileStorageService()
    {
        _uploadsRoot = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads");
    }

    public async Task<string> SaveFileAsync(Stream stream, string fileName, string category)
    {
        var safeCategory = SanitizeSegment(category);
        var extension = Path.GetExtension(fileName);
        var safeName = SanitizeFileName(Path.GetFileNameWithoutExtension(fileName));
        var storedName = $"{Guid.NewGuid():N}_{safeName}{extension}";
        var directory = Path.Combine(_uploadsRoot, safeCategory);

        Directory.CreateDirectory(directory);

        var fullPath = Path.Combine(directory, storedName);
        await using var fileStream = File.Create(fullPath);
        await stream.CopyToAsync(fileStream);

        return $"/uploads/{safeCategory}/{storedName}";
    }

    public Task DeleteFileAsync(string relativeUrl)
    {
        if (string.IsNullOrWhiteSpace(relativeUrl) || !relativeUrl.StartsWith("/uploads/", StringComparison.OrdinalIgnoreCase))
            return Task.CompletedTask;

        var relativePath = relativeUrl.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
        var fullPath = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", relativePath));
        var uploadsRoot = Path.GetFullPath(_uploadsRoot);

        if (fullPath.StartsWith(uploadsRoot, StringComparison.OrdinalIgnoreCase) && File.Exists(fullPath))
            File.Delete(fullPath);

        return Task.CompletedTask;
    }

    private static string SanitizeSegment(string value)
    {
        var cleaned = new string(value.Where(c => char.IsLetterOrDigit(c) || c == '-' || c == '_').ToArray());
        return string.IsNullOrWhiteSpace(cleaned) ? "files" : cleaned;
    }

    private static string SanitizeFileName(string value)
    {
        var invalid = Path.GetInvalidFileNameChars();
        var cleaned = new string(value.Where(c => !invalid.Contains(c)).ToArray()).Trim();
        return string.IsNullOrWhiteSpace(cleaned) ? "upload" : cleaned;
    }
}
