import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/domain/mystery_logic.dart';
import 'package:pokepod/features/mystery/mystery_controller.dart';

import 'support/support.dart';

MysteryRecord win([int guesses = 3]) =>
    MysteryRecord(guesses: guesses, won: true);
const loss = MysteryRecord(guesses: kMysteryMaxGuesses, won: false);

void main() {
  group('streaks', () {
    test('no history', () {
      final s = calculateStreaks({}, '2026-10-21');
      expect((s.current, s.best), (0, 0));
    });

    test('consecutive wins ending today', () {
      final s = calculateStreaks({
        '2026-10-19': win(),
        '2026-10-20': win(),
        '2026-10-21': win(),
      }, '2026-10-21');
      expect((s.current, s.best), (3, 3));
    });

    test('an unfinished new day does not reset the streak', () {
      final s = calculateStreaks({
        '2026-10-19': win(),
        '2026-10-20': win(),
      }, '2026-10-21');
      expect((s.current, s.best), (2, 2));
    });

    test('a skipped day breaks the current streak but not the best', () {
      final s = calculateStreaks({
        '2026-10-10': win(),
        '2026-10-11': win(),
        '2026-10-12': win(),
        '2026-10-14': win(),
      }, '2026-10-14');
      expect((s.current, s.best), (1, 3));
    });

    test('winning after missing a day does not extend the old streak', () {
      final s = calculateStreaks({
        '2026-10-17': win(),
        '2026-10-18': win(),
        '2026-10-20': win(),
      }, '2026-10-20');
      expect((s.current, s.best), (1, 2));
    });

    test(
      'a missed day, still unplayed today, has already ended the streak',
      () {
        final s = calculateStreaks({
          '2026-10-17': win(),
          '2026-10-18': win(),
        }, '2026-10-21');
        expect(s.current, 0);
        expect(s.best, 2);
      },
    );

    test('a loss today ends the streak immediately', () {
      final s = calculateStreaks({
        '2026-10-19': win(),
        '2026-10-20': win(),
        '2026-10-21': loss,
      }, '2026-10-21');
      expect((s.current, s.best), (0, 2));
    });

    test('works across month, year and leap-day boundaries', () {
      final year = calculateStreaks({
        '2026-12-30': win(),
        '2026-12-31': win(),
        '2027-01-01': win(),
      }, '2027-01-01');
      expect((year.current, year.best), (3, 3));
      final leap = calculateStreaks({
        '2024-02-28': win(),
        '2024-02-29': win(),
        '2024-03-01': win(),
      }, '2024-03-01');
      expect((leap.current, leap.best), (3, 3));
      final noLeap = calculateStreaks({
        '2025-02-28': win(),
        '2025-03-01': win(),
      }, '2025-03-01');
      expect((noLeap.current, noLeap.best), (2, 2));
    });

    test('losses do not count toward the best streak', () {
      final s = calculateStreaks({
        '2026-10-01': win(),
        '2026-10-02': loss,
        '2026-10-03': win(),
      }, '2026-10-03');
      expect((s.current, s.best), (1, 1));
    });
  });

  group('playing a day', () {
    const today = '2026-10-21';

    test('a correct guess wins; duplicates cannot double-count it', () async {
      final prefs = await mockPrefs();
      final c = makeContainer(prefs);
      final n = c.read(mysteryProvider.notifier);
      expect(c.read(mysteryProvider).statusFor(today), ChallengeStatus.ready);
      expect(n.submitGuess(5, answerId: 10, today: today), GuessResult.wrong);
      expect(
        c.read(mysteryProvider).statusFor(today),
        ChallengeStatus.inProgress,
      );
      expect(n.submitGuess(5, answerId: 10, today: today), GuessResult.ignored);
      expect(n.submitGuess(10, answerId: 10, today: today), GuessResult.won);
      expect(
        n.submitGuess(10, answerId: 10, today: today),
        GuessResult.ignored,
      );
      expect(
        n.submitGuess(11, answerId: 10, today: today),
        GuessResult.ignored,
      );
      final state = c.read(mysteryProvider);
      expect(state.history, hasLength(1));
      expect(state.history[today]!.guesses, 2);
      expect(state.history[today]!.won, isTrue);
      expect(state.history[today]!.target, 10);
      expect(state.statusFor(today), ChallengeStatus.won);
      expect(state.guessesLeft(today), 0);
    });

    test(
      'six wrong guesses lose the day, reveal the answer and lock the game',
      () async {
        final prefs = await mockPrefs();
        final c = makeContainer(prefs);
        final n = c.read(mysteryProvider.notifier);
        for (var i = 1; i < kMysteryMaxGuesses; i++) {
          expect(
            c.read(mysteryProvider).guessesLeft(today),
            kMysteryMaxGuesses - (i - 1),
          );
          expect(
            n.submitGuess(100 + i, answerId: 10, today: today),
            GuessResult.wrong,
          );
        }
        expect(c.read(mysteryProvider).guessesLeft(today), 1);
        expect(
          n.submitGuess(200, answerId: 10, today: today),
          GuessResult.lost,
        );
        final state = c.read(mysteryProvider);
        expect(state.statusFor(today), ChallengeStatus.lost);
        expect(state.history[today]!.won, isFalse);
        expect(state.history[today]!.guesses, kMysteryMaxGuesses);
        expect(
          state.targetFor(today),
          10,
          reason: 'the answer is kept so it can be shown',
        );
        expect(state.guessesLeft(today), 0);

        // No further guesses, not even the right one, and nothing changes.
        final before = state.guessesFor(today);
        expect(
          n.submitGuess(10, answerId: 10, today: today),
          GuessResult.ignored,
        );
        expect(
          n.submitGuess(300, answerId: 10, today: today),
          GuessResult.ignored,
        );
        expect(c.read(mysteryProvider).guessesFor(today), before);
        expect(c.read(mysteryProvider).history[today]!.won, isFalse);
      },
    );

    test('a loss ends the winning streak; a win extends it only once', () async {
      final prefs = await mockPrefs({
        'mystery.v1':
            '{"history":{"2026-10-19":{"g":2,"w":true},"2026-10-20":{"g":3,"w":true}}}',
      });
      final c = makeContainer(
        prefs,
        overrides: [todayKeyProvider.overrideWithValue(today)],
      );
      expect(
        c.read(mysteryStreaksProvider).current,
        2,
        reason: 'a new unplayed day keeps the streak',
      );

      final n = c.read(mysteryProvider.notifier);
      n.submitGuess(10, answerId: 10, today: today);
      n.submitGuess(10, answerId: 10, today: today);
      n.submitGuess(10, answerId: 10, today: today);
      expect(c.read(mysteryStreaksProvider).current, 3);
      expect(c.read(mysteryStreaksProvider).best, 3);

      final lossPrefs = await mockPrefs({
        'mystery.v1':
            '{"history":{"2026-10-19":{"g":2,"w":true},"2026-10-20":{"g":3,"w":true}}}',
      });
      final c2 = makeContainer(
        lossPrefs,
        overrides: [todayKeyProvider.overrideWithValue(today)],
      );
      final n2 = c2.read(mysteryProvider.notifier);
      for (var i = 1; i <= kMysteryMaxGuesses; i++) {
        n2.submitGuess(100 + i, answerId: 10, today: today);
      }
      expect(c2.read(mysteryStreaksProvider).current, 0);
      expect(c2.read(mysteryStreaksProvider).best, 2);
    });

    test('invalid Pokémon numbers are never counted as guesses', () async {
      final prefs = await mockPrefs();
      final c = makeContainer(prefs);
      final n = c.read(mysteryProvider.notifier);
      expect(n.submitGuess(0, answerId: 10, today: today), GuessResult.ignored);
      expect(
        n.submitGuess(-4, answerId: 10, today: today),
        GuessResult.ignored,
      );
      expect(
        n.submitGuess(1026, answerId: 10, today: today),
        GuessResult.ignored,
      );
      expect(c.read(mysteryProvider).guessesFor(today), isEmpty);
    });
  });

  group('persistence, restarts and the answer never being re-rolled', () {
    const today = '2026-10-21';

    test('an in-progress day is restored exactly', () async {
      final prefs = await mockPrefs();
      makeContainer(prefs)
          .read(mysteryProvider.notifier)
          .submitGuess(5, answerId: 10, today: today);

      final restarted = makeContainer(prefs);
      final s = restarted.read(mysteryProvider);
      expect(s.guessesFor(today), [5]);
      expect(s.statusFor(today), ChallengeStatus.inProgress);
      expect(s.targetFor(today), 10);
      expect(s.guessesFor('2026-10-22'), isEmpty);
    });

    test(
      'a finished day stays finished after a restart and cannot be replayed',
      () async {
        final prefs = await mockPrefs();
        final first = makeContainer(prefs);
        for (var i = 1; i <= kMysteryMaxGuesses; i++) {
          first
              .read(mysteryProvider.notifier)
              .submitGuess(100 + i, answerId: 10, today: today);
        }
        final restarted = makeContainer(prefs);
        expect(
          restarted.read(mysteryProvider).statusFor(today),
          ChallengeStatus.lost,
        );
        final n = restarted.read(mysteryProvider.notifier);
        expect(
          n.submitGuess(10, answerId: 10, today: today),
          GuessResult.ignored,
        );
        expect(
          restarted.read(mysteryProvider).statusFor(today),
          ChallengeStatus.lost,
        );

        final won = await mockPrefs();
        makeContainer(won)
            .read(mysteryProvider.notifier)
            .submitGuess(10, answerId: 10, today: today);
        final again = makeContainer(won);
        expect(
          again.read(mysteryProvider).statusFor(today),
          ChallengeStatus.won,
        );
        expect(
          again
              .read(mysteryProvider.notifier)
              .submitGuess(11, answerId: 10, today: today),
          GuessResult.ignored,
        );
        expect(again.read(mysteryProvider).history, hasLength(1));
      },
    );

    test(
      'opening a day stores its answer and reopening does not change it',
      () async {
        final prefs = await mockPrefs();
        final c = makeContainer(prefs);
        c.read(mysteryProvider.notifier).ensureDay(today);
        expect(c.read(mysteryProvider).activeTarget, mysteryAnswerId(today));

        final reopened = makeContainer(prefs);
        expect(
          reopened.read(mysteryProvider).targetFor(today),
          mysteryAnswerId(today),
        );
        reopened.read(mysteryProvider.notifier).ensureDay(today);
        expect(
          reopened.read(mysteryProvider).activeTarget,
          mysteryAnswerId(today),
        );
      },
    );

    test('a saved answer is trusted over recomputing it', () async {
      final prefs = await mockPrefs({
        'mystery.v1':
            '{"v":2,"history":{},"active":"$today","target":42,"guesses":[1,2],"seen":"$today"}',
      });
      final s = makeContainer(prefs).read(mysteryProvider);
      expect(s.targetFor(today), 42);
      expect(s.guessesFor(today), [1, 2]);
    });

    test(
      'data saved by the previous version keeps its answer and its progress',
      () async {
        // No stored answer: the old version chose it with the legacy picker.
        final prefs = await mockPrefs({
          'mystery.v1':
              '{"history":{"2026-10-20":{"g":3,"w":true}},"active":"$today","guesses":[1,2]}',
        });
        final c = makeContainer(prefs);
        var s = c.read(mysteryProvider);
        expect(s.targetFor(today), legacyMysteryAnswerId(today));
        expect(s.history['2026-10-20']!.won, isTrue);

        c.read(mysteryProvider.notifier).ensureDay(today);
        s = c.read(mysteryProvider);
        expect(s.activeTarget, legacyMysteryAnswerId(today));
        expect(s.guessesFor(today), [
          1,
          2,
        ], reason: 'guesses are not wiped by migration');
        expect(
          s.history['2026-10-20']!.won,
          isTrue,
          reason: 'history is not overwritten',
        );

        // The next day uses the new selection.
        expect(s.targetFor('2026-10-22'), mysteryAnswerId('2026-10-22'));
      },
    );

    test(
      'an older finished day without a stored answer still resolves one',
      () async {
        final prefs = await mockPrefs({
          'mystery.v1': '{"history":{"$today":{"g":2,"w":true}}}',
        });
        final s = makeContainer(prefs).read(mysteryProvider);
        expect(s.statusFor(today), ChallengeStatus.won);
        expect(s.targetFor(today), legacyMysteryAnswerId(today));
      },
    );

    test(
      'a new day starts fresh; yesterday\'s unfinished guesses are not carried over',
      () async {
        final prefs = await mockPrefs();
        final c = makeContainer(prefs);
        final n = c.read(mysteryProvider.notifier);
        n.submitGuess(5, answerId: 10, today: today);
        n.ensureDay('2026-10-22');
        final s = c.read(mysteryProvider);
        expect(s.guessesFor('2026-10-22'), isEmpty);
        expect(s.statusFor('2026-10-22'), ChallengeStatus.ready);
        expect(
          s.history,
          isEmpty,
          reason: 'the unfinished day is simply not played',
        );
        expect(s.targetFor('2026-10-22'), mysteryAnswerId('2026-10-22'));
      },
    );

    test(
      'turning the clock back cannot reopen or replay an earlier day',
      () async {
        final prefs = await mockPrefs();
        final c = makeContainer(
          prefs,
          overrides: [todayKeyProvider.overrideWithValue('2026-10-21')],
        );
        final n = c.read(mysteryProvider.notifier);
        n.submitGuess(10, answerId: 10, today: '2026-10-22');
        expect(c.read(mysteryProvider).lastSeen, '2026-10-22');
        expect(
          c.read(challengeDayProvider),
          '2026-10-22',
          reason: 'the later day wins',
        );

        expect(
          n.submitGuess(11, answerId: 12, today: '2026-10-21'),
          GuessResult.ignored,
        );
        n.ensureDay('2026-10-21');
        expect(c.read(mysteryProvider).activeDate, '2026-10-22');
      },
    );

    test('corrupt or partial data is handled', () async {
      expect(
        makeContainer(
          await mockPrefs({'mystery.v1': '[1,2'}),
        ).read(mysteryProvider).history,
        isEmpty,
      );
      final partial = makeContainer(
        await mockPrefs({
          'mystery.v1':
              '{"history":{"2026-10-20":{"g":3,"w":true},"bad":{"g":1}}}',
        }),
      ).read(mysteryProvider);
      expect(partial.history.keys, ['2026-10-20']);
    });
  });

  group('the date', () {
    test(
      'todayKey follows the injected clock, midnight, month, year and leap-day rolls',
      () async {
        final prefs = await mockPrefs();
        var now = DateTime(2026, 10, 21, 23, 59, 30);
        final c = makeContainer(
          prefs,
          overrides: [clockProvider.overrideWithValue(() => now)],
        );
        expect(c.read(todayKeyProvider), '2026-10-21');

        void tickTo(DateTime next) {
          now = next;
          c.read(dayTickProvider.notifier).state++;
        }

        tickTo(DateTime(2026, 10, 22, 0, 0, 1));
        expect(c.read(todayKeyProvider), '2026-10-22');
        tickTo(DateTime(2026, 12, 31, 23, 59));
        expect(c.read(todayKeyProvider), '2026-12-31');
        tickTo(DateTime(2027, 1, 1, 0, 0, 1));
        expect(c.read(todayKeyProvider), '2027-01-01');
        tickTo(DateTime(2028, 2, 29, 12));
        expect(c.read(todayKeyProvider), '2028-02-29');
        tickTo(DateTime(2028, 3, 1));
        expect(c.read(todayKeyProvider), '2028-03-01');
      },
    );

    test('ChallengeStatus covers every state', () {
      expect(ChallengeStatus.values, hasLength(4));
      expect(
        listEquals(ChallengeStatus.values.map((e) => e.name).toList(), [
          'ready',
          'inProgress',
          'won',
          'lost',
        ]),
        isTrue,
      );
    });
  });
}
