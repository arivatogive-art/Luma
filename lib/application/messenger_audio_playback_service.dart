// Pfad: lib/application/messenger_audio_playback_service.dart

import 'dart:async';

import 'package:just_audio/just_audio.dart';

class MessengerAudioPlaybackSnapshot {
  final String? messageId;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool hasError;

  const MessengerAudioPlaybackSnapshot({
    required this.messageId,
    required this.isPlaying,
    required this.position,
    required this.duration,
    this.hasError = false,
  });

  static const MessengerAudioPlaybackSnapshot idle =
      MessengerAudioPlaybackSnapshot(
    messageId: null,
    isPlaying: false,
    position: Duration.zero,
    duration: Duration.zero,
  );

  double get progress {
    if (duration.inMilliseconds <= 0) return 0.0;

    final raw = position.inMilliseconds / duration.inMilliseconds;

    if (raw.isNaN || raw.isInfinite) return 0.0;
    if (raw < 0.0) return 0.0;
    if (raw > 1.0) return 1.0;

    return raw;
  }
}

class MessengerAudioPlaybackService {
  MessengerAudioPlaybackService();

  final AudioPlayer _player = AudioPlayer();
  final StreamController<MessengerAudioPlaybackSnapshot> _snapshotController =
      StreamController<MessengerAudioPlaybackSnapshot>.broadcast();

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  String? _activeMessageId;
  Duration _activeDuration = Duration.zero;
  bool _isDisposed = false;

  Stream<MessengerAudioPlaybackSnapshot> get snapshots =>
      _snapshotController.stream;

  Future<void> initialize() async {
    if (_isDisposed) return;

    await _positionSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _durationSubscription?.cancel();

    _positionSubscription = _player.positionStream.listen((position) {
      _emitSnapshot(position: position);
    });

    _durationSubscription = _player.durationStream.listen((duration) {
      _activeDuration = duration ?? _activeDuration;
      _emitSnapshot(position: _player.position);
    });

    _playerStateSubscription = _player.playerStateStream.listen((state) async {
      if (_isDisposed) return;

      if (state.processingState == ProcessingState.completed) {
        await stop();
        return;
      }

      _emitSnapshot(position: _player.position);
    });
  }

  Future<void> toggle({
    required String messageId,
    required String source,
    required Duration fallbackDuration,
  }) async {
    if (_isDisposed) return;

    final cleanedMessageId = messageId.trim();
    final cleanedSource = source.trim();

    if (cleanedMessageId.isEmpty || cleanedSource.isEmpty) {
      await stop();
      return;
    }

    if (_activeMessageId == cleanedMessageId) {
      if (_player.playing) {
        await pause();
      } else {
        await _player.play();
        _emitSnapshot(position: _player.position);
      }
      return;
    }

    await play(
      messageId: cleanedMessageId,
      source: cleanedSource,
      fallbackDuration: fallbackDuration,
    );
  }

  Future<void> play({
    required String messageId,
    required String source,
    required Duration fallbackDuration,
  }) async {
    if (_isDisposed) return;

    final cleanedMessageId = messageId.trim();
    final cleanedSource = source.trim();

    if (cleanedMessageId.isEmpty || cleanedSource.isEmpty) {
      await stop();
      return;
    }

    try {
      await _player.stop();

      _activeMessageId = cleanedMessageId;
      _activeDuration = fallbackDuration.inMilliseconds > 0
          ? fallbackDuration
          : Duration.zero;

      _emitSnapshot(
        position: Duration.zero,
        isPlayingOverride: true,
      );

      if (_isRemoteSource(cleanedSource)) {
        await _player.setUrl(cleanedSource);
      } else {
        await _player.setFilePath(cleanedSource);
      }

      await _player.play();
      _emitSnapshot(position: _player.position);
    } catch (_) {
      await _handlePlaybackFailure(cleanedMessageId);
    }
  }

  Future<void> pause() async {
    if (_isDisposed) return;

    await _player.pause();
    _emitSnapshot(position: _player.position);
  }

  Future<void> stop() async {
    if (_isDisposed) return;

    try {
      await _player.stop();
    } catch (_) {
      // Stop must remain safe.
    }

    _activeMessageId = null;
    _activeDuration = Duration.zero;
    _emit(MessengerAudioPlaybackSnapshot.idle);
  }

  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    await _positionSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _durationSubscription?.cancel();

    try {
      await _player.dispose();
    } catch (_) {
      // Disposal should remain best-effort.
    }

    await _snapshotController.close();
  }

  Future<void> _handlePlaybackFailure(String messageId) async {
    try {
      await _player.stop();
    } catch (_) {
      // Failure cleanup must never crash the controller.
    }

    _activeMessageId = null;
    _activeDuration = Duration.zero;

    _emit(
      MessengerAudioPlaybackSnapshot(
        messageId: messageId,
        isPlaying: false,
        position: Duration.zero,
        duration: Duration.zero,
        hasError: true,
      ),
    );
  }

  void _emitSnapshot({
    required Duration position,
    bool? isPlayingOverride,
  }) {
    final messageId = _activeMessageId;

    if (messageId == null || messageId.isEmpty) {
      _emit(MessengerAudioPlaybackSnapshot.idle);
      return;
    }

    final duration = _player.duration ?? _activeDuration;

    _emit(
      MessengerAudioPlaybackSnapshot(
        messageId: messageId,
        isPlaying: isPlayingOverride ?? _player.playing,
        position: _clampPosition(position, duration),
        duration: duration,
      ),
    );
  }

  Duration _clampPosition(Duration position, Duration duration) {
    if (position.isNegative) return Duration.zero;
    if (duration.inMilliseconds <= 0) return position;
    if (position > duration) return duration;
    return position;
  }

  void _emit(MessengerAudioPlaybackSnapshot snapshot) {
    if (_isDisposed) return;
    if (_snapshotController.isClosed) return;

    _snapshotController.add(snapshot);
  }

  bool _isRemoteSource(String source) {
    final cleaned = source.trim().toLowerCase();

    return cleaned.startsWith('http://') ||
        cleaned.startsWith('https://') ||
        cleaned.startsWith('blob:') ||
        cleaned.startsWith('data:');
  }
}
