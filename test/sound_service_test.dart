import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/core/audio/sound_service.dart';

import 'support/support.dart';

void main() {
  group('SoundService targeted stop', () {
    test('stopping one effect leaves every other effect playing', () async {
      final backend = FakeSoundBackend();
      final service = SoundService(backend);
      await service.play(Sfx.game);
      await service.play(Sfx.correct);

      await service.stop(Sfx.game);

      expect(backend.stopped, [Sfx.game], reason: 'only the game sound');
      expect(backend.isPlaying(Sfx.game), isFalse);
      expect(
        backend.isPlaying(Sfx.correct),
        isTrue,
        reason: 'an unrelated sound must keep playing',
      );
    });

    test('an effect that already finished costs no platform work', () async {
      final backend = FakeSoundBackend();
      final service = SoundService(backend);
      await service.play(Sfx.game);
      backend.finishSound(Sfx.game);

      await service.stop(Sfx.game);

      expect(backend.stopped, isEmpty, reason: 'nothing was still playing');
    });

    test(
      'stop waits for a play that has not reached the platform yet',
      () async {
        final backend = FakeSoundBackend(
          playDelay: const Duration(milliseconds: 60),
        );
        final service = SoundService(backend);

        final playing = service.play(Sfx.game);
        final stopping = service.stop(Sfx.game);
        await Future.wait([playing, stopping]);

        expect(backend.stopped, [
          Sfx.game,
        ], reason: 'a stop must not lose the race against the play it cancels');
        expect(backend.isPlaying(Sfx.game), isFalse);
      },
    );

    test('an effect can play again straight after a stop', () async {
      final backend = FakeSoundBackend();
      final service = SoundService(backend);
      await service.play(Sfx.game);
      backend.finishSound(Sfx.game);
      await service.stop(Sfx.game);

      await service.play(Sfx.game);

      expect(backend.played, [Sfx.game, Sfx.game]);
    });

    test(
      'a duplicate trigger inside the repeat window is still dropped',
      () async {
        final backend = FakeSoundBackend();
        final service = SoundService(backend);

        await service.play(Sfx.correct);
        await service.play(Sfx.correct);

        expect(backend.played, [Sfx.correct]);
      },
    );
  });

  group('SoundService.playToCompletion', () {
    test('resolves once the sound has actually finished', () async {
      final backend = FakeSoundBackend(autoComplete: false);
      final service = SoundService(backend);

      final done = service.playToCompletion(Sfx.splash);
      expect(backend.playedToCompletion, [Sfx.splash]);
      expect(backend.isPlaying(Sfx.splash), isTrue, reason: 'sound is running');

      backend.finishSound(Sfx.splash);
      await done;

      expect(backend.isPlaying(Sfx.splash), isFalse);
      expect(
        backend.stopped,
        isEmpty,
        reason: 'finished normally, no stop needed',
      );
    });

    test('a sound that never finishes is bounded and stopped', () async {
      final backend = FakeSoundBackend(autoComplete: false);
      final service = SoundService(backend);

      final watch = Stopwatch()..start();
      await service.playToCompletion(
        Sfx.splash,
        maxWait: const Duration(milliseconds: 80),
      );
      watch.stop();

      expect(
        watch.elapsedMilliseconds,
        greaterThanOrEqualTo(60),
        reason: 'the fallback timeout must actually bound the wait',
      );
      expect(backend.stopped, [
        Sfx.splash,
      ], reason: 'no sound may outlive the wait');
    });

    test('a failing audio system never throws at the caller', () async {
      final backend = FakeSoundBackend(autoComplete: false)
        ..playError = StateError('no audio device');
      final service = SoundService(backend);

      await service.playToCompletion(Sfx.splash);
      await service.play(Sfx.game);

      expect(
        backend.stopped,
        isEmpty,
        reason: 'a failed start has nothing to stop',
      );
    });
  });
}
