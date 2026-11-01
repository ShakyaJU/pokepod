import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/core/utils/formatters.dart';
import 'package:pokepod/domain/generations.dart';
import 'package:pokepod/domain/mystery_logic.dart';

String key(DateTime start, int plusDays) =>
    utcDateKey(start.add(Duration(days: plusDays)));

void main() {
  final start = DateTime.utc(2026, 10, 21);

  group(
    'root cause of the old bias (legacy picker, kept only for migration)',
    () {
      test('legacy answers are unchanged so saved days keep their answer', () {
        expect(stableHash('abc'), 17414191);
        expect(legacyMysteryAnswerId('2026-10-20'), 777);
        expect(legacyMysteryAnswerId('2026-10-21'), 778);
        expect(legacyMysteryAnswerId('2026-01-01'), 786);
      });

      test(
        'the legacy hash produced consecutive Pokédex numbers on consecutive days',
        () {
          final ids = [
            for (var i = 0; i < 14; i++)
              legacyMysteryAnswerId(key(DateTime.utc(2026, 10, 15), i)),
          ];
          var steps = 0;
          for (var i = 1; i < ids.length; i++) {
            if (ids[i] == ids[i - 1] + 1) {
              steps++;
            }
          }
          expect(
            steps,
            greaterThanOrEqualTo(8),
            reason: 'documents why one generation repeated: $ids',
          );
        },
      );
    },
  );

  group('eligible Pokémon', () {
    test(
      'the full national dex is eligible, with every generation present',
      () {
        expect(kEligibleDexIds.length, 1025);
        expect(kEligibleDexIds.first, 1);
        expect(kEligibleDexIds.last, 1025);
        expect(
          {for (final id in kEligibleDexIds) generationOf(id)},
          {1, 2, 3, 4, 5, 6, 7, 8, 9},
        );
      },
    );

    test('malformed, out-of-range and duplicate records are dropped', () {
      final cleaned = sanitizeEligibleIds([
        25,
        null,
        0,
        -3,
        1026,
        10034,
        25,
        150,
        1025,
        1,
      ]);
      expect(cleaned, [1, 25, 150, 1025]);
    });

    test('an empty pool is an error, never a silent fallback', () {
      expect(
        () => pickDailyTarget('2026-10-21', eligible: const []),
        throwsArgumentError,
      );
    });
  });

  group('distribution', () {
    test(
      'over one full cycle every Pokémon is chosen exactly once, from all generations',
      () {
        final epoch = DateTime.utc(2024, 1, 1);
        final picks = [
          for (var i = 0; i < 1025; i++) mysteryAnswerId(key(epoch, i)),
        ];
        expect(picks.toSet().length, 1025);
        expect(
          {for (final id in picks) generationOf(id)},
          {1, 2, 3, 4, 5, 6, 7, 8, 9},
        );
        expect(picks.every((id) => id >= 1 && id <= 1025), isTrue);
      },
    );

    test('there is no consecutive-number pattern between days', () {
      final ids = [
        for (var i = 0; i < 365; i++) mysteryAnswerId(key(start, i)),
      ];
      var consecutive = 0;
      for (var i = 1; i < ids.length; i++) {
        if (ids[i] == ids[i - 1] + 1) {
          consecutive++;
        }
      }
      expect(consecutive, lessThan(5));
      expect(
        ids.first == 1,
        isFalse,
        reason: 'does not start with the first Pokémon',
      );
    });

    test('a couple of months already spans most generations', () {
      final gens = {
        for (var i = 0; i < 60; i++)
          generationOf(mysteryAnswerId(key(start, i))),
      };
      expect(gens.length, greaterThanOrEqualTo(7));
    });

    test('Generation VII is neither dominant nor missing over a year', () {
      var gen7 = 0;
      for (var i = 0; i < 365; i++) {
        if (generationOf(mysteryAnswerId(key(start, i))) == 7) {
          gen7++;
        }
      }
      // Generation VII is 88 of 1025 species (8.6%).
      expect(gen7 / 365, inInclusiveRange(0.04, 0.14));
    });

    test(
      'a small custom pool is covered completely and not always in order',
      () {
        final pool = [10, 20, 30, 40, 50];
        final epoch = DateTime.utc(2024, 1, 1);
        final cycle = [
          for (var i = 0; i < 5; i++)
            pickDailyTarget(key(epoch, i), eligible: pool),
        ];
        expect(cycle.toSet(), pool.toSet());
        final secondCycle = [
          for (var i = 5; i < 10; i++)
            pickDailyTarget(key(epoch, i), eligible: pool),
        ];
        expect(secondCycle.toSet(), pool.toSet());
        // Across many days the pool is never reduced to its first element.
        final many = {
          for (var i = 0; i < 50; i++)
            pickDailyTarget(key(epoch, i), eligible: pool),
        };
        expect(many.length, 5);
      },
    );

    test('different cycles use different orders', () {
      final epoch = DateTime.utc(2024, 1, 1);
      final first = [
        for (var i = 0; i < 20; i++) mysteryAnswerId(key(epoch, i)),
      ];
      final second = [
        for (var i = 1025; i < 1045; i++) mysteryAnswerId(key(epoch, i)),
      ];
      expect(first, isNot(second));
    });

    test('the specimen of the day is independent of the mystery answer', () {
      var same = 0;
      for (var i = 0; i < 365; i++) {
        final k = key(start, i);
        if (mysteryAnswerId(k) == specimenOfDayId(k)) {
          same++;
        }
      }
      expect(same, lessThan(10));
    });
  });

  group('stability and dates', () {
    test('the same date always resolves to the same Pokémon', () {
      final once = mysteryAnswerId('2026-10-21');
      for (var i = 0; i < 5; i++) {
        expect(mysteryAnswerId('2026-10-21'), once);
      }
      expect(specimenOfDayId('2026-10-21'), specimenOfDayId('2026-10-21'));
    });

    test('a new date resolves to a new, valid Pokémon', () {
      final a = mysteryAnswerId('2026-10-21');
      final b = mysteryAnswerId('2026-10-22');
      expect(a, isNot(b));
      expect(b, inInclusiveRange(1, 1025));
    });

    test(
      'day numbers are consecutive across month ends, year ends and leap days',
      () {
        expect(dayNumber('2024-03-01') - dayNumber('2024-02-29'), 1);
        expect(dayNumber('2024-02-29') - dayNumber('2024-02-28'), 1);
        expect(
          dayNumber('2025-03-01') - dayNumber('2025-02-28'),
          1,
          reason: 'no leap day in 2025',
        );
        expect(dayNumber('2025-01-01') - dayNumber('2024-12-31'), 1);
        expect(dayNumber('2026-11-01') - dayNumber('2026-10-31'), 1);
        expect(
          dayNumber('2026-03-29') - dayNumber('2026-03-28'),
          1,
          reason: 'unaffected by daylight saving',
        );
        expect(dayNumber('2024-01-01'), 0);
        expect(dayNumber('2023-12-31'), -1);
      },
    );

    test(
      'dates before the first cycle and invalid keys still give valid answers',
      () {
        expect(mysteryAnswerId('2020-05-05'), inInclusiveRange(1, 1025));
        expect(mysteryAnswerId('not-a-date'), inInclusiveRange(1, 1025));
      },
    );

    test(
      'the local date key follows the calendar day at midnight and on boundaries',
      () {
        expect(localDateKey(DateTime(2026, 10, 21, 23, 59, 59)), '2026-10-21');
        expect(localDateKey(DateTime(2026, 10, 22, 0, 0, 0)), '2026-10-22');
        expect(localDateKey(DateTime(2026, 12, 31, 23, 59)), '2026-12-31');
        expect(localDateKey(DateTime(2027, 1, 1)), '2027-01-01');
        expect(localDateKey(DateTime(2024, 2, 29, 12)), '2024-02-29');
        expect(localDateKey(DateTime(2024, 3, 1)), '2024-03-01');
      },
    );
  });
}
