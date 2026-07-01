// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum FocusStatus { focused, warning, distracted, noFace, inactive }

class FocusDetectionService {
  static const _wsUrl = String.fromEnvironment(
    'FOCUS_WS_URL',
    defaultValue: 'ws://localhost:8000/ws/detect',
  );

  static const _maxReconnectAttempts = 5;

  html.VideoElement? _videoEl;
  html.MediaStream?  _stream;
  WebSocketChannel?  _channel;
  StreamSubscription? _sub;
  Timer? _captureTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  final _statusCtrl = StreamController<FocusStatus>.broadcast();
  Stream<FocusStatus> get statusStream => _statusCtrl.stream;

  FocusStatus _current = FocusStatus.inactive;
  FocusStatus get current => _current;

  bool _active = false;
  bool get isActive => _active;

  bool _capturing = false;

  Future<bool> start() async {
    if (_active) return true;

    // Warn when served over HTTPS but WS URL is not wss:// — browsers block it.
    if (html.window.location.protocol == 'https:' &&
        _wsUrl.startsWith('ws://')) {
      debugPrint(
        '[Focus] WARNING: page is HTTPS but FOCUS_WS_URL uses ws:// — '
        'connection will be blocked by the browser. Rebuild with '
        '--dart-define=FOCUS_WS_URL=wss://<your-host>/ws/detect',
      );
    }

    try {
      // Camera
      _stream = await html.window.navigator.mediaDevices!.getUserMedia(
        {'video': {'facingMode': 'user', 'width': 640, 'height': 480}, 'audio': false},
      );
      _videoEl = html.VideoElement()
        ..srcObject = _stream
        ..autoplay = true
        ..muted = true;
      await _videoEl!.onLoadedMetadata.first;

      _active = true;
      _reconnectAttempts = 0;
      _connectWs();

      // Capture loop — send a frame every 800ms
      _captureTimer = Timer.periodic(const Duration(milliseconds: 800), (_) => _capture());
      _emit(FocusStatus.focused);
      return true;
    } catch (e) {
      debugPrint('[Focus] start failed: $e');
      _cleanup();
      return false;
    }
  }

  void _connectWs() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
      );
    } catch (e) {
      debugPrint('[Focus] WS connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_active) return; // stop() was called — don't reconnect
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[Focus] Max reconnect attempts reached — giving up');
      _emit(FocusStatus.inactive);
      return;
    }
    final delaySecs = 1 << _reconnectAttempts; // 1, 2, 4, 8, 16
    _reconnectAttempts++;
    debugPrint(
      '[Focus] WS disconnected — reconnecting in ${delaySecs}s '
      '(attempt $_reconnectAttempts/$_maxReconnectAttempts)',
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySecs), () {
      if (_active) _connectWs();
    });
  }

  void stop() {
    _cleanup();
    _emit(FocusStatus.inactive);
  }

  void _capture() {
    if (_videoEl == null || _capturing || _channel == null) return;
    if (_videoEl!.videoWidth == 0) return;
    _capturing = true;
    try {
      final canvas = html.CanvasElement(
          width: _videoEl!.videoWidth, height: _videoEl!.videoHeight);
      canvas.context2D.drawImage(_videoEl!, 0, 0);
      final b64 = canvas.toDataUrl('image/jpeg', 0.8).split(',').last;
      _channel?.sink.add(b64);
    } finally {
      _capturing = false;
    }
  }

  void _onMessage(dynamic data) {
    try {
      final j = jsonDecode(data as String) as Map<String, dynamic>;
      final state = j['attention_state'] as String? ?? 'focused';
      final status = switch (state) {
        'distracted' || 'sleeping' || 'no_face' => FocusStatus.distracted,
        'warning' || 'drowsy' || 'low_confidence' => FocusStatus.warning,
        'multiple_faces' || 'occluded' => FocusStatus.warning,
        _ => FocusStatus.focused,
      };
      _emit(status);
    } catch (_) {}
  }

  void _emit(FocusStatus s) {
    _current = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  void _cleanup() {
    _captureTimer?.cancel();
    _captureTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    _stream?.getTracks().forEach((t) => t.stop());
    _stream = null;
    _videoEl = null;
    _active = false;
  }

  void dispose() {
    _cleanup();
    _statusCtrl.close();
  }
}
