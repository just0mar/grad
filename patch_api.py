import re

path = 'C:/Users/engMa/Desktop/New folder/Equipex/eq-master/lib/services/api_client.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

if 'dart:typed_data' not in content:
    content = content.replace(\"import 'dart:async';\", \"import 'dart:async';\\nimport 'dart:typed_data';\")

content = content.replace(
'''  Future<dynamic> uploadFile(
    String path, {
    required String fileField,
    required String filePath,
    required String fileName,
    Map<String, String>? fields,
  }) async {''',
'''  Future<dynamic> uploadFile(
    String path, {
    required String fileField,
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
    Map<String, String>? fields,
  }) async {''')

content = content.replace(
'''    request.files.add(
      await http.MultipartFile.fromPath(
        fileField,
        filePath,
        filename: fileName,
      ),
    );''',
'''    if (fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(fileField, fileBytes, filename: fileName));
    } else if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath, filename: fileName));
    }''')

content = content.replace(
'''      retry.files.add(
        await http.MultipartFile.fromPath(
          fileField,
          filePath,
          filename: fileName,
        ),
      );''',
'''      if (fileBytes != null) {
        retry.files.add(http.MultipartFile.fromBytes(fileField, fileBytes, filename: fileName));
      } else if (filePath != null) {
        retry.files.add(await http.MultipartFile.fromPath(fileField, filePath, filename: fileName));
      }''')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Patched api_client.dart')
