import 'package:dio/dio.dart';
import 'api_client.dart';

class DocumentInfo {
  final String sourceFile;
  final int chunkCount;
  final String assetType;

  const DocumentInfo({
    required this.sourceFile,
    required this.chunkCount,
    required this.assetType,
  });

  factory DocumentInfo.fromApi(Map<String, dynamic> d) => DocumentInfo(
        sourceFile: d['source_file'] as String,
        chunkCount: (d['chunk_count'] as num).toInt(),
        assetType: d['asset_type'] as String? ?? '',
      );

  // "my_document.pdf" → "My Document"
  String get displayName {
    final name = sourceFile.contains('/')
        ? sourceFile.split('/').last
        : sourceFile;
    final dotIdx = name.lastIndexOf('.');
    final base = dotIdx > 0 ? name.substring(0, dotIdx) : name;
    return base.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  }

  // "my_document.PDF" → "PDF"
  String get ext {
    final dotIdx = sourceFile.lastIndexOf('.');
    if (dotIdx < 0) return 'FILE';
    return sourceFile.substring(dotIdx + 1).toUpperCase();
  }
}

class DocumentService {
  static Future<List<DocumentInfo>> listDocuments() async {
    final resp = await apiClient.get('/api/v1/documents');
    final docs = resp.data['documents'] as List;
    return docs
        .map((d) => DocumentInfo.fromApi(d as Map<String, dynamic>))
        .toList();
  }

  static Future<void> uploadDocument(
      List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    await apiClient.post(
      '/api/v1/documents/upload',
      data: formData,
      options: Options(
        // First upload triggers model downloads on the server (bge-m3 ~570 MB,
        // EasyOCR ~150 MB for scanned PDFs). Allow up to 10 minutes.
        receiveTimeout: const Duration(minutes: 10),
      ),
    );
  }

  /// Upload multiple files in one request via POST /documents/batch-upload.
  /// Returns a list of per-file results: {filename, status, chunks, error}.
  static Future<List<Map<String, dynamic>>> batchUploadDocuments(
      List<({String name, List<int> bytes})> files) async {
    final formData = FormData.fromMap({
      'files': files
          .map((f) => MultipartFile.fromBytes(f.bytes, filename: f.name))
          .toList(),
    });
    final resp = await apiClient.post(
      '/api/v1/documents/batch-upload',
      data: formData,
      options: Options(receiveTimeout: const Duration(minutes: 15)),
    );
    final results = (resp.data as Map<String, dynamic>)['results'] as List? ?? [];
    return results.cast<Map<String, dynamic>>();
  }

  /// URL for downloading the original file from the backend.
  static String downloadUrl(String sourceFile) {
    final encoded = Uri.encodeComponent(sourceFile);
    return '${apiClient.options.baseUrl}/api/v1/documents/$encoded/content';
  }
}
