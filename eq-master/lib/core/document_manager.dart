import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';

import '../services/file_cache_service.dart';
import 'app_localizations.dart';

class DocumentManager {
  /// Consistently downloads and opens a document, extracting the proper file extension
  /// from the original file name so the OS can choose the right viewer (e.g. PDF viewer).
  static Future<void> viewDocument(
    BuildContext context, {
    required String downloadUrl,
    required String originalFileName,
    String? contentType,
  }) async {
    // Show loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context).downloadingDocument),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      // Extract the extension from the original file name
      final ext = originalFileName.contains('.')
          ? '.${originalFileName.split('.').last}'
          : '';

      final fileCache = FileCacheService.instance;
      final tempFile = await fileCache.getFile(
        downloadUrl,
        extension: ext,
        contentType: contentType,
      );

      if (!context.mounted) return;

      // Dismiss the loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // If the backend sent a generic binary type or empty string, do NOT pass it to OpenFilex.
      // Passing null forces Android/iOS to deduce the perfect MIME type from the file extension (.pdf, etc.)
      final String? safeType = (contentType == null || 
                                contentType.trim().isEmpty || 
                                contentType.contains('octet-stream')) 
          ? null 
          : contentType;

      // Open with the device's default app
      final result = await OpenFilex.open(
        tempFile.path,
        type: safeType,
      );

      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open document: ${result.message}')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download document: $e')),
      );
    }
  }

  /// Consistently wraps the file picker to handle errors and UI smoothly.
  static Future<FilePickerResult?> pickDocument({
    required BuildContext context,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool withData = false,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        withData: withData,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final fixedFiles = result.files.map((file) {
          String newName = file.name;
          
          // Test if it's true: Print the exact name Flutter received
          print('DEBUG [DocumentManager]: Picked file original name: ${file.name}, OS reported extension: ${file.extension}');
          
          // Prevent it: If the OS stripped the extension from the name, force it back on!
          if (!newName.contains('.') && file.extension != null && file.extension!.isNotEmpty) {
            newName = '$newName.${file.extension}';
            print('DEBUG [DocumentManager]: OS stripped extension! Forcing it back on: $newName');
          }
          
          return PlatformFile(
            path: file.path,
            name: newName,
            size: file.size,
            bytes: file.bytes,
            readStream: file.readStream,
            identifier: file.identifier,
          );
        }).toList();
        
        return FilePickerResult(fixedFiles);
      }

      return result;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).filePickerError(e.toString())),
          ),
        );
      }
      return null;
    }
  }
}
