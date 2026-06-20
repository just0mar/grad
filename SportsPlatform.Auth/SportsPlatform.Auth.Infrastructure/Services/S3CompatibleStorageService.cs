using System;
using System.IO;
using System.Threading.Tasks;
using Amazon.S3;
using Amazon.S3.Transfer;
using Amazon.S3.Model;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using SportsPlatform.Auth.Core.Interfaces;

namespace SportsPlatform.Auth.Infrastructure.Services;

public class S3CompatibleStorageService : IFileStorageService
{
    private readonly IAmazonS3 _s3Client;
    private readonly string _bucketName;
    private readonly string _serviceUrl;
    private readonly ILogger<S3CompatibleStorageService> _logger;

    public S3CompatibleStorageService(IConfiguration config, ILogger<S3CompatibleStorageService> logger)
    {
        _logger = logger;
        _bucketName = config["Storage:BucketName"] ?? throw new ArgumentNullException("Storage:BucketName is missing");
        _serviceUrl = config["Storage:ServiceUrl"] ?? throw new ArgumentNullException("Storage:ServiceUrl is missing");
        var accessKey = config["Storage:AccessKey"] ?? throw new ArgumentNullException("Storage:AccessKey is missing");
        var secretKey = config["Storage:SecretKey"] ?? throw new ArgumentNullException("Storage:SecretKey is missing");

        var s3Config = new AmazonS3Config
        {
            ServiceURL = _serviceUrl,
            ForcePathStyle = true // Required for many S3-compatible providers like MinIO or some R2 setups
        };

        _s3Client = new AmazonS3Client(accessKey, secretKey, s3Config);
    }

    public async Task<string> SaveFileAsync(Stream stream, string fileName, string category, string? contentType = null)
    {
        var safeCategory = SanitizeSegment(category);
        var extension = Path.GetExtension(fileName);
        var safeName = SanitizeFileName(Path.GetFileNameWithoutExtension(fileName));
        var storedName = $"{Guid.NewGuid():N}_{safeName}{extension}";
        var objectKey = $"uploads/{safeCategory}/{storedName}";

        try
        {
            var uploadRequest = new TransferUtilityUploadRequest
            {
                InputStream = stream,
                Key = objectKey,
                BucketName = _bucketName,
                ContentType = contentType ?? "application/octet-stream"
            };

            var fileTransferUtility = new TransferUtility(_s3Client);
            await fileTransferUtility.UploadAsync(uploadRequest);

            // Construct the public URL
            // Adjust based on the provider. If ServiceURL has no trailing slash:
            var publicUrl = $"{_serviceUrl.TrimEnd('/')}/{_bucketName}/{objectKey}";
            return publicUrl;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading file to S3 compatible storage.");
            throw;
        }
    }

    public async Task DeleteFileAsync(string relativeUrl)
    {
        if (string.IsNullOrWhiteSpace(relativeUrl)) return;

        // Try to extract the object key from the full URL
        try
        {
            var uri = new Uri(relativeUrl);
            var path = uri.AbsolutePath.TrimStart('/');
            // path is like "equipex/uploads/category/filename.ext" if bucket name is in path
            // Remove bucket name from path if necessary, but with ForcePathStyle=true, object keys don't include bucket name.
            var keyStartIndex = path.IndexOf("uploads/");
            if (keyStartIndex >= 0)
            {
                var objectKey = path.Substring(keyStartIndex);
                var deleteObjectRequest = new DeleteObjectRequest
                {
                    BucketName = _bucketName,
                    Key = objectKey
                };
                await _s3Client.DeleteObjectAsync(deleteObjectRequest);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting file from S3 compatible storage.");
        }
    }

    private string SanitizeSegment(string segment)
    {
        var invalidChars = Path.GetInvalidPathChars();
        return string.Join("_", segment.Split(invalidChars, StringSplitOptions.RemoveEmptyEntries));
    }

    private string SanitizeFileName(string name)
    {
        var invalidChars = Path.GetInvalidFileNameChars();
        return string.Join("_", name.Split(invalidChars, StringSplitOptions.RemoveEmptyEntries));
    }
}