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

/// Status of one upload job returned by GET /api/v1/documents/jobs/{id}.
class UploadJobStatus {
  final String jobId;
  final String filename;
  final String status; // pending | processing | completed | failed
  final String? error;
  final int? chunksCreated;

  const UploadJobStatus({
    required this.jobId,
    required this.filename,
    required this.status,
    this.error,
    this.chunksCreated,
  });

  factory UploadJobStatus.fromJson(Map<String, dynamic> j) => UploadJobStatus(
        jobId: j['job_id'] as String,
        filename: j['filename'] as String? ?? '',
        status: j['status'] as String? ?? 'pending',
        error: j['error'] as String?,
        chunksCreated: j['chunks_created'] as int?,
      );

  bool get isTerminal => status == 'completed' || status == 'failed';
}

class DocumentService {
  static Future<List<DocumentInfo>> listDocuments() async {
    final resp = await apiClient.get('/api/v1/documents');
    final docs = resp.data['documents'] as List;
    return docs
        .map((d) => DocumentInfo.fromApi(d as Map<String, dynamic>))
        .toList();
  }

  /// Start uploading multiple files. Returns immediately with job IDs — the
  /// server ingests each file in the background. Use [getJobStatus] to poll.
  static Future<List<UploadJobStatus>> startBatchUpload(
      List<({String name, List<int> bytes})> files) async {
    final formData = FormData.fromMap({
      'files': files
          .map((f) => MultipartFile.fromBytes(f.bytes, filename: f.name))
          .toList(),
    });
    final resp = await apiClient.post(
      '/api/v1/documents/batch-upload',
      data: formData,
      options: Options(
        // Only wait for the server to accept and save the raw files — fast.
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    final submitted = (resp.data['submitted'] as List?) ?? [];
    return submitted
        .map((j) => UploadJobStatus(
              jobId: j['job_id'] as String,
              filename: j['filename'] as String,
              status: 'processing',
            ))
        .toList();
  }

  /// Poll the status of one upload job.
  static Future<UploadJobStatus> getJobStatus(String jobId) async {
    final resp = await apiClient.get('/api/v1/documents/jobs/$jobId');
    return UploadJobStatus.fromJson(resp.data as Map<String, dynamic>);
  }

  /// URL for downloading the original file from the backend.
  static String downloadUrl(String sourceFile) {
    final encoded = Uri.encodeComponent(sourceFile);
    return '${apiClient.options.baseUrl}/api/v1/documents/$encoded/content';
  }
}
