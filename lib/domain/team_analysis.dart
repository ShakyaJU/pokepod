import 'type_chart.dart';

/// Result of analysing a team's typing. Offensive coverage and defensive
/// weaknesses are kept strictly separate.
///
/// Offensive coverage is **STAB-based**: it assumes each member can use
/// moves of its own types, because the app does not know actual movesets.
class TeamAnalysis {
  const TeamAnalysis({
    required this.size,
    required this.weakCounts,
    required this.resistCounts,
    required this.immuneCounts,
    required this.coveredTypes,
    required this.uncoveredTypes,
    required this.majorWeaknesses,
    required this.suggestions,
  });

  final int size;

  /// For each attacking type: how many members take more than neutral damage.
  final Map<String, int> weakCounts;
  final Map<String, int> resistCounts;
  final Map<String, int> immuneCounts;

  /// Defending types hit super effectively by at least one member's own types.
  final List<String> coveredTypes;
  final List<String> uncoveredTypes;

  /// Attacking types where weak members outnumber resisting/immune ones by 2+.
  final List<String> majorWeaknesses;
  final List<String> suggestions;
}

class TeamAnalyzer {
  const TeamAnalyzer._();

  /// [memberTypes] holds one list of type names per team member.
  static TeamAnalysis analyze(List<List<String>> memberTypes) {
    final weak = {for (final t in kTypes) t: 0};
    final resist = {for (final t in kTypes) t: 0};
    final immune = {for (final t in kTypes) t: 0};

    for (final types in memberTypes) {
      for (final attacker in kTypes) {
        final m = TypeChart.against(attacker, types);
        if (m == 0) {
          immune[attacker] = immune[attacker]! + 1;
        } else if (m < 1) {
          resist[attacker] = resist[attacker]! + 1;
        } else if (m > 1) {
          weak[attacker] = weak[attacker]! + 1;
        }
      }
    }

    final offensiveTypes = <String>{for (final types in memberTypes) ...types};
    final covered = <String>[];
    final uncovered = <String>[];
    for (final defender in kTypes) {
      final hit = offensiveTypes.any((a) => TypeChart.single(a, defender) > 1);
      (hit ? covered : uncovered).add(defender);
    }

    final major = <String>[
      for (final t in kTypes)
        if (weak[t]! - resist[t]! - immune[t]! >= 2) t,
    ];

    final suggestions = <String>[];
    if (memberTypes.isNotEmpty) {
      for (final attacker in major) {
        final resisters = [
          for (final t in kTypes)
            if (TypeChart.single(attacker, t) < 1) t,
        ].take(4).map(_cap).join(', ');
        suggestions.add(
          '${weak[attacker]} members are weak to ${_cap(attacker)} while only '
          '${resist[attacker]! + immune[attacker]!} resist it. Adding a '
          '$resisters type would help.',
        );
      }
      if (uncovered.isNotEmpty && memberTypes.length >= 2) {
        final shown = uncovered.take(4);
        for (final defender in shown) {
          final attackers = TypeChart.attackersSuperEffectiveAgainst(
            defender,
          ).take(4).map(_cap).join(', ');
          suggestions.add(
            'No member\'s own types hit ${_cap(defender)} super effectively. '
            '$attackers moves or types would.',
          );
        }
      }
    }

    return TeamAnalysis(
      size: memberTypes.length,
      weakCounts: weak,
      resistCounts: resist,
      immuneCounts: immune,
      coveredTypes: covered,
      uncoveredTypes: uncovered,
      majorWeaknesses: major,
      suggestions: suggestions,
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
