import '../core/utils/formatters.dart';
import '../data/models/pokemon.dart';

/// One verifiable relationship between two Pokémon. Every connection states
/// the data it was derived from.
class Connection {
  const Connection({
    required this.otherId,
    required this.otherName,
    required this.kind,
    required this.title,
    required this.explanation,
    required this.score,
  });

  final int otherId;
  final String otherName;
  final String kind;
  final String title;
  final String explanation;
  final double score;
}

/// Finds explainable connections between [base] and each of [candidates].
///
/// Scores only decide ordering: surprising relationships (different types but
/// the same ability, equal totals with different strengths) rank above
/// obvious ones.
List<Connection> findConnections(
  PokemonDetail base,
  List<PokemonDetail> candidates, {
  Set<int> evolutionRelatives = const {},
  int limit = 6,
}) {
  final out = <Connection>[];
  final baseShare = _shares(base);

  for (final c in candidates) {
    if (c.id == base.id) {
      continue;
    }
    final other = c.displayName;
    final me = base.displayName;

    if (evolutionRelatives.contains(c.id)) {
      out.add(
        Connection(
          otherId: c.id,
          otherName: other,
          kind: 'evolution',
          title: 'Same evolutionary family',
          explanation:
              '$other and $me appear in the same PokéAPI evolution chain.',
          score: 0.5,
        ),
      );
    }

    final sharedTypes = [
      for (final t in base.types)
        if (c.types.contains(t)) t,
    ];
    final sharedAbilities = [
      for (final a in base.abilities)
        if (c.abilities.any((b) => b.name == a.name)) a,
    ];

    if (sharedAbilities.isNotEmpty) {
      final names = sharedAbilities.map((a) => a.displayName).join(', ');
      final differentTypes = sharedTypes.isEmpty;
      out.add(
        Connection(
          otherId: c.id,
          otherName: other,
          kind: 'ability',
          title: differentTypes
              ? 'Same ability, different types'
              : 'Shared ability',
          explanation:
              '$me and $other can both have $names'
              '${differentTypes ? ', despite sharing no type' : ''}.',
          score: differentTypes ? 0.85 : 0.6,
        ),
      );
    }

    if (sharedTypes.isNotEmpty) {
      out.add(
        Connection(
          otherId: c.id,
          otherName: other,
          kind: 'type',
          title: 'Shared typing',
          explanation:
              'Both are ${sharedTypes.map(titleCase).join(' and ')} type.',
          score: 0.3 + 0.05 * sharedTypes.length,
        ),
      );
    }

    if (base.stats.isNotEmpty && c.stats.isNotEmpty) {
      final distance = _l1(baseShare, _shares(c));
      final bTop = base.topStat;
      final cTop = c.topStat;
      if (bTop != null &&
          cTop != null &&
          bTop.name == cTop.name &&
          distance <= 0.15) {
        out.add(
          Connection(
            otherId: c.id,
            otherName: other,
            kind: 'profile',
            title: 'Near-identical stat shape',
            explanation:
                'Both put their largest share of base stats into '
                '${statLabel(bTop.name)} (${bTop.value} for $me, ${cTop.value} for '
                '$other), and the rest of their spread is very similar.',
            score: 0.9 - distance,
          ),
        );
      }

      final totalGap = (base.statTotal - c.statTotal).abs();
      if (totalGap <= 25 &&
          bTop != null &&
          cTop != null &&
          bTop.name != cTop.name) {
        out.add(
          Connection(
            otherId: c.id,
            otherName: other,
            kind: 'contrast',
            title: 'Similar power, different strengths',
            explanation:
                'Base stat totals are ${base.statTotal} ($me) and '
                '${c.statTotal} ($other), but $me peaks in ${statLabel(bTop.name)} '
                '(${bTop.value}) while $other peaks in ${statLabel(cTop.name)} '
                '(${cTop.value}).',
            score: 0.95 - totalGap / 500,
          ),
        );
      }
    }
  }

  out.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.otherId.compareTo(b.otherId);
  });
  return out.take(limit).toList();
}

List<double> _shares(PokemonDetail p) {
  final total = p.statTotal;
  return [for (final k in kStatOrder) total == 0 ? 0.0 : p.stat(k) / total];
}

double _l1(List<double> a, List<double> b) {
  var sum = 0.0;
  for (var i = 0; i < a.length; i++) {
    sum += (a[i] - b[i]).abs();
  }
  return sum;
}
