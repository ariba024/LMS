import 'api_client.dart';

class ChatService {
  /// Ask a question using the RAG endpoint.
  /// Returns the AI's answer text.
  static Future<String> ask(
    String question, {
    String? sourceFile,
    int nChunks = 5,
  }) async {
    final resp = await apiClient.post('/api/v1/chat', data: {
      'question': question,
      if (sourceFile != null) 'source_file': sourceFile,
      'n_chunks': nChunks,
    });
    return resp.data['answer'] as String;
  }
}
