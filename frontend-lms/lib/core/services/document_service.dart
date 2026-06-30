import 'dart:typed_data';
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

class DocumentChunk {
  final int chunkIndex;
  final String? sectionHeading;
  final int? pageNumber;
  final int? slideNumber;
  final int tokenCount;
  final String text;

  const DocumentChunk({
    required this.chunkIndex,
    this.sectionHeading,
    this.pageNumber,
    this.slideNumber,
    required this.tokenCount,
    required this.text,
  });

  factory DocumentChunk.fromJson(Map<String, dynamic> j) => DocumentChunk(
        chunkIndex: (j['chunk_index'] as num).toInt(),
        sectionHeading: j['section_heading'] as String?,
        pageNumber: j['page_number'] as int?,
        slideNumber: j['slide_number'] as int?,
        tokenCount: (j['token_count'] as num? ?? 0).toInt(),
        text: j['text'] as String? ?? '',
      );
}

class DocumentContent {
  final String sourceFile;
  final String assetType;
  final int totalChunks;
  final String fullText;
  final List<DocumentChunk> chunks;

  const DocumentContent({
    required this.sourceFile,
    required this.assetType,
    required this.totalChunks,
    required this.fullText,
    required this.chunks,
  });

  factory DocumentContent.fromJson(Map<String, dynamic> j) => DocumentContent(
        sourceFile: j['source_file'] as String,
        assetType: j['asset_type'] as String? ?? '',
        totalChunks: (j['total_chunks'] as num).toInt(),
        fullText: j['full_text'] as String? ?? '',
        chunks: (j['chunks'] as List)
            .map((c) => DocumentChunk.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
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

  /// Fetch the extracted text content (chunks) for a document.
  static Future<DocumentContent> getDocumentContent(String sourceFile) async {
    final encoded = Uri.encodeComponent(sourceFile);
    final resp = await apiClient.get('/api/v1/documents/$encoded/content');
    return DocumentContent.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Fetch the raw bytes of the original uploaded file.
  static Future<({Uint8List bytes, String mimeType})> getFileBytes(
      String sourceFile) async {
    final encoded = Uri.encodeComponent(sourceFile);
    final resp = await apiClient.get(
      '/api/v1/documents/$encoded/file',
      options: Options(responseType: ResponseType.bytes),
    );
    final mime =
        resp.headers.value('content-type') ?? 'application/octet-stream';
    return (bytes: Uint8List.fromList(resp.data as List<int>), mimeType: mime);
  }

  /// Delete a document from the vector store, BM25 index, and uploads directory.
  static Future<void> deleteDocument(String sourceFile) async {
    final encoded = Uri.encodeComponent(sourceFile);
    await apiClient.delete('/api/v1/documents/$encoded');
  }
}
