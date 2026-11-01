import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/data/models/pokemon.dart';
import 'package:pokepod/domain/achievements.dart';
import 'package:pokepod/domain/compare_logic.dart';
import 'package:pokepod/domain/connections.dart';
import 'package:pokepod/domain/evolution_layout.dart';
import 'package:pokepod/domain/research_rules.dart';
import 'package:pokepod/domain/team_analysis.dart';
import 'package:pokepod/domain/type_chart.dart';

import 'support/support.dart';

void main() {
  group('TypeChart', () {
    test('single-type multipliers', () {
      expect(TypeChart.single('fire', 'grass'), 2);
      expect(TypeChart.single('water', 'fire'), 2);
      expect(TypeChart.single('fire', 'water'), 0.5);
      expect(TypeChart.single('normal', 'ghost'), 0);
      expect(TypeChart.single('ground', 'flying'), 0);
      expect(TypeChart.single('electric', 'ground'), 0);
      expect(TypeChart.single('dragon', 'fairy'), 0);
      expect(TypeChart.single('fairy', 'dragon'), 2);
      expect(TypeChart.single('poison', 'steel'), 0);
      expect(TypeChart.single('psychic', 'dark'), 0);
      expect(TypeChart.single('ghost', 'normal'), 0);
      expect(TypeChart.single('normal', 'normal'), 1);
    });

    test('dual types multiply', () {
      expect(TypeChart.against('rock', ['fire', 'flying']), 4);
      expect(TypeChart.against('electric', ['water', 'flying']), 4);
      expect(TypeChart.against('fire', ['bug', 'steel']), 4);
      expect(TypeChart.against('ice', ['dragon', 'flying']), 4);
      expect(TypeChart.against('grass', ['fire', 'flying']), 0.25);
      expect(TypeChart.against('ground', ['fire', 'flying']), 0);
      expect(TypeChart.against('electric', ['water', 'ground']), 0);
      expect(TypeChart.against('water', ['fire', 'ground']), 4);
      expect(TypeChart.against('fire', ['water', 'grass']), 1);
    });

    test('immunity beats a weakness in the other type', () {
      expect(TypeChart.against('ground', ['flying', 'fire']), 0);
    });

    test('defensive profile covers all 18 types', () {
      final profile = TypeChart.defensiveProfile(['fire', 'flying']);
      expect(profile.length, 18);
      expect(profile['rock'], 4);
      expect(profile['ground'], 0);
      expect(profile['bug'], 0.25);
    });

    test('every type appears in the chart as attacker and defender', () {
      for (final t in kTypes) {
        expect(TypeChart.superEffectiveTargets(t), isA<List<String>>());
      }
      expect(TypeChart.attackersSuperEffectiveAgainst('ground'), [
        'water',
        'grass',
        'ice',
      ]);
      expect(TypeChart.superEffectiveTargets('steel'), [
        'ice',
        'rock',
        'fairy',
      ]);
    });

    test('formatMultiplier', () {
      expect(formatMultiplier(0), '×0');
      expect(formatMultiplier(0.25), '×¼');
      expect(formatMultiplier(0.5), '×½');
      expect(formatMultiplier(2), '×2');
      expect(formatMultiplier(4), '×4');
    });
  });

  group('TeamAnalyzer', () {
    test(
      'counts weaknesses, resistances and immunities per attacking type',
      () {
        final a = TeamAnalyzer.analyze([
          ['fire', 'flying'],
          ['water', 'ground'],
        ]);
        expect(a.weakCounts['rock'], 1);
        expect(a.resistCounts['rock'], 1);
        expect(a.immuneCounts['ground'], 1);
        expect(a.immuneCounts['electric'], 1);
        expect(a.size, 2);
      },
    );

    test('flags major shared weaknesses with an explainable suggestion', () {
      final a = TeamAnalyzer.analyze([
        ['fire'],
        ['electric'],
        ['rock'],
      ]);
      expect(a.weakCounts['ground'], 3);
      expect(a.majorWeaknesses, contains('ground'));
      expect(
        a.suggestions.any((s) => s.contains('3 members are weak to Ground')),
        isTrue,
      );
      expect(
        a.suggestions.any((s) => s.contains('Grass, Flying, Bug')),
        isTrue,
      );
    });

    test('offensive coverage is separate from defensive weaknesses', () {
      final a = TeamAnalyzer.analyze([
        ['fire'],
        ['water'],
      ]);
      expect(
        a.coveredTypes,
        containsAll(['grass', 'ice', 'bug', 'steel', 'ground', 'rock']),
      );
      expect(a.uncoveredTypes, contains('normal'));
      expect(a.coveredTypes.length + a.uncoveredTypes.length, 18);
    });

    test('an empty team yields no suggestions', () {
      final a = TeamAnalyzer.analyze(const []);
      expect(a.size, 0);
      expect(a.suggestions, isEmpty);
      expect(a.majorWeaknesses, isEmpty);
    });
  });

  group('ResearchRules', () {
    test('progress moves up one stage at a time', () {
      expect(
        ResearchRules.canTransition(
          ResearchState.unseen,
          ResearchState.discovered,
        ),
        isTrue,
      );
      expect(
        ResearchRules.canTransition(
          ResearchState.unseen,
          ResearchState.studied,
        ),
        isFalse,
      );
      expect(
        ResearchRules.canTransition(
          ResearchState.discovered,
          ResearchState.mastered,
        ),
        isFalse,
      );
      expect(
        ResearchRules.canTransition(
          ResearchState.studied,
          ResearchState.mastered,
        ),
        isTrue,
      );
    });

    test('users may step back down and no-op changes are rejected', () {
      expect(
        ResearchRules.canTransition(
          ResearchState.mastered,
          ResearchState.unseen,
        ),
        isTrue,
      );
      expect(
        ResearchRules.canTransition(
          ResearchState.studied,
          ResearchState.discovered,
        ),
        isTrue,
      );
      expect(
        ResearchRules.canTransition(
          ResearchState.studied,
          ResearchState.studied,
        ),
        isFalse,
      );
      expect(ResearchRules.next(ResearchState.mastered), isNull);
      expect(
        ResearchRules.next(ResearchState.unseen),
        ResearchState.discovered,
      );
    });
  });

  group('layoutEvolution', () {
    EvoNode leaf(int id) => EvoNode(id: id, name: 'p$id');

    bool overlaps(PlacedNode a, PlacedNode b) {
      const w = 120.0;
      const h = 150.0;
      final ra = Rect.fromCenter(center: a.center, width: w, height: h);
      final rb = Rect.fromCenter(center: b.center, width: w, height: h);
      return ra.overlaps(rb);
    }

    test('single node', () {
      final layout = layoutEvolution(leaf(1));
      expect(layout.nodes, hasLength(1));
      expect(layout.edges, isEmpty);
      expect(layout.size, const Size(184, 214));
    });

    test('linear chain stays on one row, left to right', () {
      final root = EvoNode(
        id: 1,
        name: 'a',
        links: [
          EvoLink(
            'Level 16',
            EvoNode(id: 2, name: 'b', links: [EvoLink('Level 36', leaf(3))]),
          ),
        ],
      );
      final layout = layoutEvolution(root);
      expect(layout.nodes.map((n) => n.center.dy).toSet(), hasLength(1));
      final xs = layout.nodes.map((n) => n.center.dx).toList();
      expect(xs, orderedEquals([...xs]..sort()));
      expect(layout.edges, hasLength(2));
      expect(
        layout.edges.map((e) => e.label),
        containsAll(['Level 16', 'Level 36']),
      );
      expect(layout.size.width, 664);
    });

    test('branching family: no overlaps, parent centred, bounded size', () {
      final chain = EvolutionChain.fromApiJson(eeveeChainJson());
      final layout = layoutEvolution(chain.root);
      expect(layout.nodes, hasLength(4));
      for (var i = 0; i < layout.nodes.length; i++) {
        for (var j = i + 1; j < layout.nodes.length; j++) {
          expect(overlaps(layout.nodes[i], layout.nodes[j]), isFalse);
        }
      }
      final root = layout.nodes.firstWhere((n) => n.depth == 0);
      final kids = layout.nodes.where((n) => n.depth == 1).toList();
      expect(root.center.dy, (kids.first.center.dy + kids.last.center.dy) / 2);
      expect(layout.size.height, 562);
      for (final n in layout.nodes) {
        expect(n.center.dx, lessThan(layout.size.width));
        expect(n.center.dy, lessThan(layout.size.height));
      }
      expect(layout.edges, hasLength(3));
    });

    test('very wide families remain overlap-free', () {
      final root = EvoNode(
        id: 1,
        name: 'eevee',
        links: [for (var i = 0; i < 8; i++) EvoLink('x$i', leaf(10 + i))],
      );
      final layout = layoutEvolution(root);
      for (var i = 0; i < layout.nodes.length; i++) {
        for (var j = i + 1; j < layout.nodes.length; j++) {
          expect(overlaps(layout.nodes[i], layout.nodes[j]), isFalse);
        }
      }
    });
  });

  group('findConnections', () {
    test('explains shared ability across different types', () {
      final base = makeDetail(
        1,
        'alpha',
        ['electric'],
        abilities: ['static'],
        atk: 100,
      );
      final other = makeDetail(
        2,
        'beta',
        ['water'],
        abilities: ['static'],
        hp: 150,
      );
      final out = findConnections(base, [other]);
      expect(out.single.kind, 'ability');
      expect(out.single.title, 'Same ability, different types');
      expect(out.single.explanation, contains('Static'));
    });

    test(
      'finds similar totals with different strengths using real numbers',
      () {
        final base = makeDetail(1, 'alpha', ['fire'], atk: 100, spe: 100);
        final other = makeDetail(2, 'beta', ['ice'], hp: 100, spe: 100);
        final out = findConnections(base, [other]);
        final contrast = out.firstWhere((c) => c.kind == 'contrast');
        expect(contrast.explanation, contains('400'));
        expect(contrast.explanation, contains('Attack'));
        expect(contrast.explanation, contains('HP'));
      },
    );

    test('marks evolutionary relatives and ranks surprising links first', () {
      final base = makeDetail(1, 'alpha', ['fire'], abilities: ['blaze']);
      final sameType = makeDetail(2, 'beta', ['fire'], atk: 150);
      final kin = makeDetail(3, 'gamma', ['dark'], def: 150);
      final out = findConnections(
        base,
        [sameType, kin],
        evolutionRelatives: {3},
      );
      expect(out.map((c) => c.kind), containsAll(['type', 'evolution']));
      expect(out.first.kind, 'evolution');
    });

    test('never connects a Pokémon to itself and respects the limit', () {
      final base = makeDetail(1, 'alpha', ['fire']);
      final many = [
        for (var i = 1; i <= 10; i++) makeDetail(i, 'p$i', ['fire']),
      ];
      final out = findConnections(base, many, limit: 4);
      expect(out.length, 4);
      expect(out.any((c) => c.otherId == 1), isFalse);
    });
  });

  group('compare logic', () {
    test('explanations are derived from real numbers', () {
      final a = makeDetail(1, 'alpha', ['fire'], atk: 100, spe: 40);
      final b = makeDetail(2, 'beta', ['grass'], hp: 150);
      final notes = explainComparison(a, b);
      expect(notes.first, contains('higher base stat total'));
      expect(notes.any((n) => n.contains('Alpha hits Beta for ×2')), isTrue);
      expect(notes.any((n) => n.contains('share no types')), isTrue);
    });

    test('equal totals and same family are reported', () {
      final a = makeDetail(1, 'alpha', ['fire']);
      final b = makeDetail(2, 'beta', ['fire']);
      final notes = explainComparison(a, b, sameFamily: true);
      expect(notes.first, contains('same base stat total (300)'));
      expect(notes.any((n) => n.contains('same evolutionary family')), isTrue);
      expect(compareStats(a, b).every((d) => d.diff == 0), isTrue);
    });
  });

  group('achievements', () {
    AchievementInput input({
      int discovered = 0,
      int studied = 0,
      int mastered = 0,
      Set<int> ids = const {},
      int bestStreak = 0,
    }) {
      return AchievementInput(
        discovered: discovered,
        studied: studied,
        mastered: mastered,
        favourites: 0,
        largestCollection: 0,
        collections: 0,
        largestTeam: 0,
        mysteryWins: 0,
        bestStreak: bestStreak,
        discoveredIds: ids,
        notes: 0,
      );
    }

    test('a brand-new profile has nothing unlocked', () {
      expect(computeAchievements(input()).where((a) => a.unlocked), isEmpty);
    });

    test('rules unlock from real counts', () {
      final list = computeAchievements(
        input(discovered: 25, mastered: 1, bestStreak: 3),
      );
      Achievement byId(String id) => list.firstWhere((a) => a.id == id);
      expect(byId('first_contact').unlocked, isTrue);
      expect(byId('field_researcher').unlocked, isTrue);
      expect(byId('cataloguer').progress, 25);
      expect(byId('cataloguer').unlocked, isFalse);
      expect(byId('mastery').unlocked, isTrue);
      expect(byId('streak_3').unlocked, isTrue);
    });

    test('Kanto Complete needs all 151 Generation I Pokémon', () {
      final all = {for (var i = 1; i <= 151; i++) i};
      final done = computeAchievements(input(ids: all, discovered: 151));
      expect(done.firstWhere((a) => a.id == 'kanto_complete').unlocked, isTrue);
      final partial = computeAchievements(
        input(ids: {...all}..remove(25), discovered: 150),
      );
      expect(
        partial.firstWhere((a) => a.id == 'kanto_complete').unlocked,
        isFalse,
      );
    });
  });
}
