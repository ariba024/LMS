import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'api_client.dart';

class VideoRenderJob {
  final String renderId;
  final String scriptId;
  final String lessonRef;
  final int? sceneIndex;
  final String lang;
  final String style;
  final String status;     // pending | processing | completed | failed
  final String ttsEngine;
  final String voice;
  final String? error;
  final double startedAt;
  final double? finishedAt;
  final bool videoReady;

  const VideoRenderJob({
    required this.renderId,
    required this.scriptId,
    required this.lessonRef,
    this.sceneIndex,
    required this.lang,
    required this.style,
    required this.status,
    required this.ttsEngine,
    this.voice = '',
    this.error,
    required this.startedAt,
    this.finishedAt,
    required this.videoReady,
  });

  factory VideoRenderJob.fromJson(Map<String, dynamic> j) => VideoRenderJob(
        renderId:   j['render_id'] as String,
        scriptId:   j['script_id'] as String,
        lessonRef:  j['lesson_ref'] as String,
        sceneIndex: j['scene_index'] as int?,
        lang:       j['lang'] as String? ?? 'en',
        style:      j['style'] as String? ?? 'animated_scene',
        status:     j['status'] as String,
        ttsEngine:  j['tts_engine'] as String? ?? '',
        voice:      j['voice'] as String? ?? '',
        error:      j['error'] as String?,
        startedAt:  (j['started_at'] as num).toDouble(),
        finishedAt: (j['finished_at'] as num?)?.toDouble(),
        videoReady: j['video_ready'] as bool? ?? false,
      );
}

class VideoService {
  /// Trigger video renders for every lesson in a course.
  /// Returns the number of jobs started (already-completed lessons are skipped).
  static Future<int> generateAll(
    String scriptId, {
    String style = 'modern',
    String lang = 'en',
    String voice = '',
  }) async {
    final params = <String, String>{'style': style, 'lang': lang};
    if (voice.isNotEmpty) params['voice'] = voice;
    final resp = await apiClient.post(
      '/api/v1/video/generate-all/$scriptId',
      queryParameters: params,
    );
    return (resp.data['jobs_started'] as num).toInt();
  }

  /// Trigger render for a lesson (or a single scene within it).
  /// Returns the number of scene jobs started.
  static Future<int> renderLesson(
    String scriptId, {
    int? moduleNumber,
    int? lessonNumber,
    int? itemIndex,
    int? sceneIndex,
    String lang = 'en',
    String style = 'modern',
    String voice = '',
  }) async {
    final resp = await apiClient.post('/api/v1/video/render', data: {
      'script_id': scriptId,
      if (moduleNumber != null) 'module_number': moduleNumber,
      if (lessonNumber != null) 'lesson_number': lessonNumber,
      if (itemIndex != null) 'item_index': itemIndex,
      if (sceneIndex != null) 'scene_index': sceneIndex,
      'lang': lang,
      'style': style,
      'voice': voice,
    });
    return (resp.data['scenes_created'] as num?)?.toInt() ?? 1;
  }

  /// List all render jobs for a course.
  static Future<List<VideoRenderJob>> listRenders(String scriptId) async {
    final resp = await apiClient.get('/api/v1/video/scripts/$scriptId/renders');
    final list = resp.data['renders'] as List;
    return list
        .map((j) => VideoRenderJob.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Poll a single render job.
  static Future<VideoRenderJob> getRenderStatus(String renderId) async {
    final resp = await apiClient.get('/api/v1/video/renders/$renderId');
    return VideoRenderJob.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Pre-generate audio for every lesson in a course (fire-and-forget).
  /// Sarvam TTS pre-warms all narrations so learners never wait for audio.
  static Future<void> generateAudio(String scriptId) async {
    await apiClient.post('/api/v1/audio/generate/$scriptId');
  }

  /// Delete a completed or failed render job (admin only).
  /// Throws a DioException if the job is still active or not found.
  static Future<void> deleteRender(String renderId) async {
    await apiClient.delete('/api/v1/video/renders/$renderId');
  }

  /// Returns the stream URL for a completed render (supports Range requests /
  /// seeking). Used as the `<video>` element src in the inline player.
  static Future<String> getStreamUrl(String renderId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_access_token') ?? '';
    final base = ApiConfig.baseUrl;
    final query = token.isNotEmpty ? '?token=${Uri.encodeComponent(token)}' : '';
    return '$base/api/v1/video/renders/$renderId/stream$query';
  }

  /// Returns the download URL for a completed render (Content-Disposition:
  /// attachment), so the browser saves it as a file.
  static Future<String> getDownloadUrl(String renderId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_access_token') ?? '';
    final base = ApiConfig.baseUrl;
    final query = token.isNotEmpty ? '?token=${Uri.encodeComponent(token)}' : '';
    return '$base/api/v1/video/renders/$renderId/download$query';
  }
}
