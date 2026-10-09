import 'package:audioplayers/audioplayers.dart';

/// Serializes native playback commands so a late load cannot restart a paused breath.
class BreathingAudio {
  AudioPlayer? _player;
  Future<void> _pending = Future.value();
  bool _disposed = false;

  Future<void> play(String phase, int duration, int remaining) =>
      _enqueue(() async {
        if (_disposed) return;
        if (phase == 'Hold') {
          await _player?.stop();
          return;
        }
        final player = _player ??= AudioPlayer();
        await player.stop();
        final name = phase == 'Breathe In' ? 'inhale' : 'exhale';
        await player.play(
          AssetSource('audio/${name}_${duration}s.wav'),
          volume: .65,
          position: Duration(seconds: duration - remaining),
        );
      });

  Future<void> stop() => _enqueue(() async {
    await _player?.stop();
  });

  Future<void> dispose() {
    _disposed = true;
    return _enqueue(() async {
      await _player?.dispose();
      _player = null;
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    // Device audio failure must not interrupt the visual exercise.
    _pending = _pending.then((_) => action()).catchError((Object error) {});
    return _pending;
  }
}
