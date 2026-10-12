import 'dart:async';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame_audio/bgm.dart';
import 'package:flutter/foundation.dart';
import '../core/settings_store.dart';

class AudioManager extends ChangeNotifier {
  AudioManager(this.settings, {this.enabled = true}) : _muted = settings.muted;
  final SettingsStore settings;
  final bool enabled;
  bool _muted;
  bool _ready = false;
  bool _suspended = false;
  bool _started = false;
  bool _musicPlaying = false;
  bool _disposed = false;
  Bgm? _bgm;
  final Map<String, AudioPool> _effects = {};
  Future<void>? _initialization;
  Future<void> _queue = Future.value();
  bool get muted => _muted;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (!enabled || _disposed) return;
    try {
      await FlameAudio.audioCache.loadAll([
        'bgm.wav',
        'jump.wav',
        'explosion.wav',
        'button.wav',
        'sector.wav',
      ]);
      if (_disposed) return;
      _bgm = Bgm(audioCache: FlameAudio.audioCache);
      await _bgm!.initialize();
      if (_disposed) return;
      // Reuse prepared native players instead of creating one on every tap.
      for (final name in ['jump', 'button', 'explosion', 'sector']) {
        final pool = await FlameAudio.createPool(
          '$name.wav',
          minPlayers: name == 'jump' ? 2 : 1,
          maxPlayers: name == 'jump' ? 2 : 1,
        );
        _effects[name] = pool;
        if (_disposed) return;
      }
      _ready = true;
      await _syncMusic();
    } catch (error) {
      debugPrint('Audio unavailable: $error');
    }
  }

  Future<void> toggleMute() async {
    if (_disposed) return;
    _muted = !_muted;
    notifyListeners();
    try {
      await settings.setMuted(_muted);
    } catch (error) {
      debugPrint('Audio setting persistence failed: $error');
    }
    await _syncMusic();
  }

  Future<void> resume() {
    _suspended = false;
    return _syncMusic();
  }

  Future<void> suspend() {
    _suspended = true;
    return _syncMusic();
  }

  Future<void> _syncMusic() {
    _queue = _queue.then((_) async {
      if (!_ready || !enabled || _disposed) return;
      final wanted = !_muted && !_suspended;
      if (wanted == _musicPlaying) return;
      try {
        if (!wanted) {
          await _bgm!.pause();
        } else if (_started) {
          await _bgm!.resume();
        } else {
          await _bgm!.play('bgm.wav', volume: 0.22);
          _started = true;
        }
        _musicPlaying = wanted;
      } catch (error) {
        debugPrint('Music unavailable: $error');
      }
    });
    return _queue;
  }

  Future<void> play(String name) async {
    if (!enabled || !_ready || _muted || _suspended || _disposed) return;
    try {
      await _effects[name]?.start(volume: name == 'explosion' ? 0.5 : 0.35);
    } catch (error) {
      debugPrint('Sound unavailable: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(() async {
      try {
        await _initialization;
        await _queue;
        for (final pool in _effects.values) {
          await pool.dispose();
        }
        _effects.clear();
        await _bgm?.dispose();
      } catch (error) {
        debugPrint('Audio cleanup failed: $error');
      }
    }());
    super.dispose();
  }
}
