import '../core/utils/formatters.dart';
import '../data/models/pokemon.dart';
import 'type_chart.dart';

class StatDiff {
  const StatDiff(this.stat, this.a, this.b);
  final String stat;
  final int a;
  final int b;
  int get diff => a - b;
}

List<StatDiff> compareStats(PokemonDetail a, PokemonDetail b) => [
  for (final k in kStatOrder) StatDiff(k, a.stat(k), b.stat(k)),
];

/// Deterministic, data-derived comparison notes. Nothing here predicts battle
/// outcomes; base stats are only one ingredient of a real battle.
List<String> explainComparison(
  PokemonDetail a,
  PokemonDetail b, {
  bool sameFamily = false,
}) {
  final notes = <String>[];
  final an = a.displayName;
  final bn = b.displayName;

  final totalDiff = a.statTotal - b.statTotal;
  if (totalDiff == 0) {
    notes.add('$an and $bn have the same base stat total (${a.statTotal}).');
  } else {
    final hi = totalDiff > 0 ? an : bn;
    final lo = totalDiff > 0 ? bn : an;
    notes.add(
      '$hi has a higher base stat total than $lo '
      '(${totalDiff > 0 ? a.statTotal : b.statTotal} vs '
      '${totalDiff > 0 ? b.statTotal : a.statTotal}, +${totalDiff.abs()}).',
    );
  }

  final diffs = compareStats(a, b);
  StatDiff? biggestA;
  StatDiff? biggestB;
  for (final d in diffs) {
    if (d.diff > 0 && (biggestA == null || d.diff > biggestA.diff)) {
      biggestA = d;
    }
    if (d.diff < 0 && (biggestB == null || d.diff < biggestB.diff)) {
      biggestB = d;
    }
  }
  if (biggestA != null) {
    notes.add(
      '$an\'s largest advantage is ${statLabel(biggestA.stat)} '
      '(${biggestA.a} vs ${biggestA.b}).',
    );
  }
  if (biggestB != null) {
    notes.add(
      '$bn\'s largest advantage is ${statLabel(biggestB.stat)} '
      '(${biggestB.b} vs ${biggestB.a}).',
    );
  }

  final speedDiff = a.stat('speed') - b.stat('speed');
  if (speedDiff != 0) {
    notes.add('${speedDiff > 0 ? an : bn} has the higher base Speed.');
  }

  final shared = [
    for (final t in a.types)
      if (b.types.contains(t)) t,
  ];
  if (shared.isNotEmpty) {
    notes.add('They share the ${shared.map(titleCase).join(' and ')} type.');
  } else if (a.types.isNotEmpty && b.types.isNotEmpty) {
    notes.add('They share no types.');
  }

  // Type matchup using each side's own types as attackers (STAB only).
  double best(List<String> attackers, List<String> defenders) {
    var m = 0.0;
    for (final t in attackers) {
      final v = TypeChart.against(t, defenders);
      if (v > m) {
        m = v;
      }
    }
    return m;
  }

  if (a.types.isNotEmpty && b.types.isNotEmpty) {
    final aOnB = best(a.types, b.types);
    final bOnA = best(b.types, a.types);
    notes.add(
      'Using their own types, $an hits $bn for ${formatMultiplier(aOnB)} '
      'and $bn hits $an for ${formatMultiplier(bOnA)}.',
    );
  }

  final sharedAbilities = [
    for (final x in a.abilities)
      if (b.abilities.any((y) => y.name == x.name)) x.displayName,
  ];
  if (sharedAbilities.isNotEmpty) {
    notes.add('Both can have ${sharedAbilities.join(', ')}.');
  }

  if (sameFamily) {
    notes.add('They belong to the same evolutionary family.');
  }
  return notes;
}
