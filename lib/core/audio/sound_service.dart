import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Short sound effects bundled with the app (`assets/sounds/`).
enum Sfx {
  /// Launch splash.
  splash('sounds/splashscreen.mp3'),

  /// Entering "Who's That Pokémon?".
  game('sounds/whos_that_pokemon.mp3'),

  /// An accepted, correct guess.
  correct('sounds/correct_guess.mp3'),

  /// An accepted, wrong guess.
  error('sounds/error.mp3'),

  /// The reminder chime. Android plays its own copy of this sound from
  /// `res/raw/notification.mp3` when a streak reminder arrives (the channel
  /// names it explicitly); this entry keeps the bundled asset available for
  /// in-app playback too.
  notification('sounds/notification.mp3');

  const Sfx(this.assetPath);

  /// Path relative to `assets/`, as expected by [AssetSource].
  final String assetPath;
}

/// Plays sounds. Replaceable so game logic can be tested without audio hardware.
abstract class SoundBackend {
  Future<void> preload(Sfx sfx);
  Future<void> play(Sfx sfx);

  /// Plays [sfx] and completes only once the sound has finished (or failed to
  /// start), so a caller can gate a screen transition on real playback.
  Future<void> playToCompletion(Sfx sfx);

  /// Stops only [sfx]; any other effect keeps playing.
  Future<void> stop(Sfx sfx);

  /// Whether [sfx] is currently playing, so a caller can skip a pointless stop.
  bool isPlaying(Sfx sfx);

  Future<void> stopAll();
  Future<void> dispose();
}

class NoopSoundBackend implements SoundBackend {
  const NoopSoundBackend();

  @override
  Future<void> preload(Sfx sfx) async {}

  @override
  Future<void> play(Sfx sfx) async {}

  @override
  Future<void> playToCompletion(Sfx sfx) async {}

  @override
  Future<void> stop(Sfx sfx) async {}

  @override
  bool isPlaying(Sfx sfx) => false;

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {}
}

/// One long-lived player per effect, so playback never allocates a player and
/// players are disposed exactly once.
class AudioplayersBackend implements SoundBackend {
  final Map<Sfx, AudioPlayer> _players = {};
  bool _disposed = false;

  Future<AudioPlayer> _playerFor(Sfx sfx) async {
    final existing = _players[sfx];
    if (existing != null) {
      return existing;
    }
    final player = AudioPlayer(playerId: 'pokepod-${sfx.name}');
    _players[sfx] = player;
    await player.setReleaseMode(ReleaseMode.stop);
    return player;
  }

  @override
  Future<void> preload(Sfx sfx) async {
    if (_disposed) {
      return;
    }
    final player = await _playerFor(sfx);
    await player.setSource(AssetSource(sfx.assetPath));
  }

  @override
  Future<void> play(Sfx sfx) async {
    if (_disposed) {
      return;
    }
    final player = await _playerFor(sfx);
    // play() restarts the sound if it is already running.
    await player.play(AssetSource(sfx.assetPath));
  }

  @override
  Future<void> playToCompletion(Sfx sfx) async {
    if (_disposed) {
      return;
    }
    final player = await _playerFor(sfx);
    // Subscribe before play() so a very short sound cannot finish unnoticed,
    // and detach again whatever happens so no listener outlives the sound.
    final finished = Completer<void>();
    final subscription = player.onPlayerComplete.listen((_) {
      if (!finished.isCompleted) {
        finished.complete();
      }
    });
    try {
      await player.play(AssetSource(sfx.assetPath));
      await finished.future;
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> stop(Sfx sfx) async {
    final player = _players[sfx];
    if (player == null) {
      return;
    }
    await player.stop();
  }

  @override
  bool isPlaying(Sfx sfx) {
    final player = _players[sfx];
    return player != null && player.state == PlayerState.playing;
  }

  @override
  Future<void> stopAll() async {
    for (final player in _players.values) {
      await player.stop();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final players = _players.values.toList();
    _players.clear();
    for (final player in players) {
      await player.dispose();
    }
  }
}

/// Plays effects for the rest of the app. Never throws: a missing or failing
/// audio system must not affect the game.
class SoundService {
  SoundService(
    this._backend, {
    this.minRepeat = const Duration(milliseconds: 250),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SoundBackend _backend;

  /// The same effect requested again within this time is dropped, so a duplicated
  /// trigger can never double-play.
  final Duration minRepeat;
  final DateTime Function() _clock;
  final Map<Sfx, DateTime> _lastPlayed = {};

  /// Play requests that have not reached the platform yet, per effect. [stop]
  /// waits for them so a sound cannot slip past a cancellation that raced it.
  final Map<Sfx, Future<void>> _starting = {};
  bool _disposed = false;

  Future<void> preload(Iterable<Sfx> effects) async {
    for (final sfx in effects) {
      if (_disposed) {
        return;
      }
      try {
        await _backend.preload(sfx);
      } catch (_) {
        // Audio is optional.
      }
    }
  }

  Future<void> play(Sfx sfx) async {
    if (_disposed) {
      return;
    }
    final now = _clock();
    final last = _lastPlayed[sfx];
    if (last != null && now.difference(last) < minRepeat) {
      return;
    }
    _lastPlayed[sfx] = now;
    final starting = _backend.play(sfx);
    _starting[sfx] = starting;
    try {
      await starting;
    } catch (_) {
      // Audio is optional.
    } finally {
      if (identical(_starting[sfx], starting)) {
        _starting.remove(sfx);
      }
    }
  }

  /// Plays [sfx] and completes when the sound has finished. Never throws and
  /// never waits longer than [maxWait]: a missing, failing or hung audio system
  /// must not block the caller, so the effect is stopped on timeout instead.
  Future<void> playToCompletion(
    Sfx sfx, {
    Duration maxWait = const Duration(seconds: 6),
  }) async {
    if (_disposed) {
      return;
    }
    final now = _clock();
    final last = _lastPlayed[sfx];
    if (last != null && now.difference(last) < minRepeat) {
      // A repeat of a sound that just played is dropped rather than restarted.
      return;
    }
    _lastPlayed[sfx] = now;
    var timedOut = false;
    final gate = Completer<void>();
    final timer = Timer(maxWait, () {
      timedOut = true;
      if (!gate.isCompleted) {
        gate.complete();
      }
    });
    try {
      await Future.any<void>([_backend.playToCompletion(sfx), gate.future]);
    } catch (_) {
      // Audio is optional: failing to start must not block the caller.
    } finally {
      timer.cancel();
    }
    if (timedOut) {
      // Bounded fallback: nothing may keep playing past the wait.
      try {
        await _backend.stop(sfx);
      } catch (_) {
        // Nothing to stop.
      }
    }
  }

  /// Stops only [sfx]; every other effect keeps playing. If the sound has
  /// already finished nothing is sent to the platform, so leaving a screen
  /// after a short sound ends costs no audio work.
  Future<void> stop(Sfx sfx) async {
    if (_disposed) {
      return;
    }
    final starting = _starting[sfx];
    if (starting != null) {
      try {
        await starting;
      } catch (_) {
        // Audio is optional.
      }
    }
    // A stopped sound may be replayed immediately: the repeat window is about
    // suppressing duplicate triggers, not time since a manual stop.
    _lastPlayed.remove(sfx);
    if (!_backend.isPlaying(sfx)) {
      return;
    }
    try {
      await _backend.stop(sfx);
    } catch (_) {
      // Nothing to stop.
    }
  }

  Future<void> stopAll() async {
    try {
      await _backend.stopAll();
    } catch (_) {
      // Nothing to stop.
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    try {
      await _backend.dispose();
    } catch (_) {
      // Already gone.
    }
  }
}

bool get _isFlutterTest =>
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

final soundBackendProvider = Provider<SoundBackend>((ref) {
  // Widget and unit tests run without audio plugins.
  final SoundBackend backend = _isFlutterTest
      ? const NoopSoundBackend()
      : AudioplayersBackend();
  ref.onDispose(() => unawaited(backend.dispose()));
  return backend;
});

final soundServiceProvider = Provider<SoundService>((ref) {
  return SoundService(ref.watch(soundBackendProvider));
});
