import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_store.dart';

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
    bool enabled = true,
  }) : _clock = clock ?? DateTime.now,
       _enabled = enabled;

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

  /// Whether effects may play at all: a synchronous mirror of
  /// [soundEffectsPrefsProvider]. The preference stays the single source of
  /// truth and [soundServiceProvider] pushes every change in here, so playback
  /// can answer on the spot instead of waiting on a load.
  bool _enabled;

  /// Bumped on every toggle so a stop queued by an earlier "off" cannot be
  /// applied after the user has turned sound back on.
  int _muteGeneration = 0;

  /// [playToCompletion] callers waiting for a mute that has not happened yet.
  /// Released the moment it does, so none of them has to run out its timeout.
  final Set<Completer<void>> _muteWaiters = {};

  /// The stored choice as the service is currently enforcing it.
  bool get isEnabled => _enabled;

  /// Applies the user's sound-effects choice.
  ///
  /// Turning sound off flips the flag immediately, releases every caller
  /// waiting on a sound to finish, waits for anything still on its way to the
  /// platform and only then silences it — so nothing can start *after* the
  /// request for silence. Each toggle takes a new generation, which makes a
  /// burst of changes safe: the last choice wins and a superseded stop is
  /// dropped rather than applied to a sound that is allowed again.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (_disposed) {
      return;
    }
    final generation = ++_muteGeneration;
    if (value) {
      return;
    }
    final waiters = _muteWaiters.toList();
    _muteWaiters.clear();
    for (final waiter in waiters) {
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
    // Let a play that is still starting land first: stopping afterwards
    // cannot lose the race against it.
    for (final starting in _starting.values.toList()) {
      try {
        await starting;
      } catch (_) {
        // Audio is optional.
      }
    }
    if (generation != _muteGeneration) {
      // Superseded while we waited; the newer toggle owns the outcome.
      return;
    }
    try {
      await _backend.stopAll();
    } catch (_) {
      // Nothing to stop.
    }
  }

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
    if (_disposed || !_enabled) {
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
    await _stopIfMuted(sfx);
  }

  /// Stops [sfx] if the choice went to "off" while it was reaching the
  /// platform, so a request that raced the toggle cannot still be heard.
  Future<void> _stopIfMuted(Sfx sfx) async {
    if (_disposed || _enabled || !_backend.isPlaying(sfx)) {
      return;
    }
    try {
      await _backend.stop(sfx);
    } catch (_) {
      // Nothing to stop.
    }
  }

  /// Plays [sfx] and completes when the sound has finished. Never throws and
  /// never waits longer than [maxWait]: a missing, failing or hung audio system
  /// must not block the caller, so the effect is stopped on timeout instead.
  /// Completes early when the user turns sound off mid-play, having stopped it.
  Future<void> playToCompletion(
    Sfx sfx, {
    Duration maxWait = const Duration(seconds: 6),
  }) async {
    if (_disposed || !_enabled) {
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
    final muted = Completer<void>();
    _muteWaiters.add(muted);
    try {
      await Future.any<void>([
        _backend.playToCompletion(sfx),
        gate.future,
        muted.future,
      ]);
    } catch (_) {
      // Audio is optional: failing to start must not block the caller.
    } finally {
      timer.cancel();
      _muteWaiters.remove(muted);
    }
    if (timedOut || !_enabled) {
      // Bounded fallback, or the user asked for silence while it played.
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

/// The user's sound-effects choice, stored with the other local preferences so
/// it survives restarts. It defaults to **on**: the app has always played
/// effects, so an installation that has never touched the switch behaves
/// exactly as it did before this setting existed.
class SoundEffectsNotifier extends Notifier<bool> {
  static const storageKey = 'soundEffects.v1';

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(storageKey) ?? true;

  void setEnabled(bool value) {
    if (state == value) {
      return;
    }
    state = value;
    ref.read(sharedPreferencesProvider).setBool(storageKey, value);
  }
}

/// Its own preference rather than a widget's local flag: this is app state, and
/// the switch, [soundServiceProvider] and any future caller must all read the
/// same single source of truth.
final soundEffectsPrefsProvider = NotifierProvider<SoundEffectsNotifier, bool>(
  SoundEffectsNotifier.new,
);

final soundServiceProvider = Provider<SoundService>((ref) {
  // Read, not watch: watching would rebuild — and therefore replace — the
  // service on every toggle, stranding the callers already holding it. main()
  // has loaded the preferences before the first frame, so the choice is known
  // before any startup sound can be requested.
  final service = SoundService(
    ref.watch(soundBackendProvider),
    enabled: ref.read(soundEffectsPrefsProvider),
  );
  ref.listen(soundEffectsPrefsProvider, (_, next) {
    unawaited(service.setEnabled(next));
  });
  return service;
});
