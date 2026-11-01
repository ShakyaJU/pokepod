import '../core/utils/formatters.dart';

const int kMysteryMaxGuesses = 6;

// ---------------------------------------------------------------------------
// Legacy selection (kept ONLY to migrate in-progress or finished days that were
// saved before the selection was rewritten, so a day is never re-rolled).
//
// Why it was replaced: this hash is almost linear in the last characters of the
// date, so consecutive days produced consecutive Pokédex numbers (777, 778,
// 779, ...). That is why the answer sat in one generation for days on end.
// ---------------------------------------------------------------------------

/// Deterministic, platform-independent string hash used by the legacy picker.
int stableHash(String input) {
  var h = 7;
  for (final unit in input.codeUnits) {
    h = (h * 131 + unit) % 2147483629;
  }
  return h;
}

/// The answer the previous version would have chosen for [dateKey].
int legacyMysteryAnswerId(String dateKey, {int poolSize = kNationalDexSize}) =>
    stableHash('mystery:$dateKey') % poolSize + 1;

// ---------------------------------------------------------------------------
// Current selection
// ---------------------------------------------------------------------------

/// Every national-dex species the app supports (1..[kNationalDexSize]).
/// No generation, type or position is favoured or excluded.
final List<int> kEligibleDexIds = List<int>.unmodifiable([
  for (var id = 1; id <= kNationalDexSize; id++) id,
]);

/// Keeps only valid, unique ids (1..[max]) in ascending order. Malformed
/// records, out-of-range ids (such as alternate-form ids) and duplicates are
/// dropped so they can never become an answer.
List<int> sanitizeEligibleIds(
  Iterable<int?> raw, {
  int max = kNationalDexSize,
}) {
  final seen = <int>{};
  for (final id in raw) {
    if (id != null && id >= 1 && id <= max) {
      seen.add(id);
    }
  }
  return seen.toList()..sort();
}

const int _mask32 = 0xFFFFFFFF;

/// 32-bit multiply that stays exact on web (no intermediate beyond 2^53).
int _mul32(int a, int b) =>
    ((a & 0xFFFF) * b + ((((a >>> 16) * b) & 0xFFFF) << 16)) & _mask32;

int _fnv1a32(String input) {
  var h = 0x811C9DC5;
  for (final unit in input.codeUnits) {
    h = (h ^ unit) & _mask32;
    h = _mul32(h, 0x01000193);
  }
  return h;
}

/// Murmur3 finaliser: spreads similar inputs over the whole 32-bit range.
int _mix32(int h) {
  var x = h & _mask32;
  x = (x ^ (x >>> 16)) & _mask32;
  x = _mul32(x, 0x85EBCA6B);
  x = (x ^ (x >>> 13)) & _mask32;
  x = _mul32(x, 0xC2B2AE35);
  x = (x ^ (x >>> 16)) & _mask32;
  return x;
}

/// Deterministic Fisher-Yates permutation of 0..n-1 for [seed].
List<int> _permutation(int n, int seed) {
  final order = List<int>.generate(n, (i) => i);
  var x = _mix32(seed);
  if (x == 0) {
    x = 0x9E3779B9;
  }
  int next() {
    x = (x ^ ((x << 13) & _mask32)) & _mask32;
    x = (x ^ (x >>> 17)) & _mask32;
    x = (x ^ ((x << 5) & _mask32)) & _mask32;
    return x;
  }

  for (var i = n - 1; i > 0; i--) {
    final j = next() % (i + 1);
    final tmp = order[i];
    order[i] = order[j];
    order[j] = tmp;
  }
  return order;
}

/// Whole days between 2024-01-01 and the calendar date [dateKey] (`YYYY-MM-DD`).
/// Pure calendar arithmetic, so it is unaffected by DST, time zones and leap days.
int dayNumber(String dateKey) {
  final date = parseDateKey(dateKey);
  if (date == null) {
    return 0;
  }
  return date.difference(DateTime.utc(2024, 1, 1)).inDays;
}

/// Picks the Pokémon for [dateKey].
///
/// The eligible list is shuffled once per cycle (one cycle = one day per
/// eligible Pokémon, 1025 days for the full dex) and each day takes the next
/// position. Over a cycle every Pokémon appears exactly once, in an order with
/// no relation to its number, generation or type, and the answer for a given
/// date never changes. [salt] gives each feature (mystery, specimen of the day)
/// its own independent order.
int pickDailyTarget(
  String dateKey, {
  List<int>? eligible,
  String salt = 'mystery',
}) {
  final pool = eligible ?? kEligibleDexIds;
  if (pool.isEmpty) {
    throw ArgumentError('There are no eligible Pokémon to choose from.');
  }
  final n = pool.length;
  final day = dayNumber(dateKey);
  final position = day % n;
  final cycle = (day - position) ~/ n;
  final order = _permutation(n, _fnv1a32('pokepod:$salt:$cycle'));
  return pool[order[position]];
}

/// Answer of the daily "Who's That Pokémon?" for [dateKey].
int mysteryAnswerId(String dateKey, {List<int>? eligible}) =>
    pickDailyTarget(dateKey, eligible: eligible, salt: 'mystery');

/// "Specimen of the day" shown on Discover and, later, on home-screen widgets.
int specimenOfDayId(String dateKey, {List<int>? eligible}) =>
    pickDailyTarget(dateKey, eligible: eligible, salt: 'specimen');

// ---------------------------------------------------------------------------
// Results and streaks
// ---------------------------------------------------------------------------

/// Where a day's challenge stands.
enum ChallengeStatus { ready, inProgress, won, lost }

class MysteryRecord {
  const MysteryRecord({required this.guesses, required this.won, this.target});

  final int guesses;
  final bool won;

  /// The Pokémon that was the answer that day (absent in data saved by older
  /// versions).
  final int? target;

  Map<String, dynamic> toJson() => {
    'g': guesses,
    'w': won,
    if (target != null) 't': target,
  };

  static MysteryRecord? tryFromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final g = raw['g'];
    final w = raw['w'];
    if (g is! num || w is! bool) {
      return null;
    }
    final t = raw['t'];
    return MysteryRecord(
      guesses: g.toInt(),
      won: w,
      target: t is int ? t : null,
    );
  }
}

class MysteryStreaks {
  const MysteryStreaks({required this.current, required this.best});
  final int current;
  final int best;
}

String _shift(String dateKey, int days) {
  final d = parseDateKey(dateKey)!;
  return utcDateKey(d.add(Duration(days: days)));
}

/// Streak rules:
/// * A win extends the streak only if the previous calendar day was also won.
/// * A day that was not played breaks the streak, but only once that day is over:
///   until today is played the streak still counts back from yesterday, so
///   merely starting a new day never resets it.
/// * A loss today ends the streak immediately.
/// * Each date counts once, so repeating a day cannot inflate anything.
MysteryStreaks calculateStreaks(
  Map<String, MysteryRecord> results,
  String todayKey,
) {
  bool won(String k) => results[k]?.won ?? false;

  // Best streak: longest run of consecutive won dates.
  final wonDays = [
    for (final e in results.entries)
      if (e.value.won && parseDateKey(e.key) != null) e.key,
  ]..sort();
  var best = 0;
  var run = 0;
  String? previous;
  for (final day in wonDays) {
    run = (previous != null && _shift(previous, 1) == day) ? run + 1 : 1;
    if (run > best) {
      best = run;
    }
    previous = day;
  }

  var current = 0;
  if (parseDateKey(todayKey) != null) {
    final today = results[todayKey];
    if (today == null || today.won) {
      var cursor = today == null ? _shift(todayKey, -1) : todayKey;
      while (won(cursor)) {
        current++;
        cursor = _shift(cursor, -1);
      }
    }
  }
  return MysteryStreaks(
    current: current,
    best: best > current ? best : current,
  );
}
