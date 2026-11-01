import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/app/design_system/rarity_label.dart';
import 'package:pokepod/app/theme/rarity.dart';
import 'package:pokepod/domain/achievements.dart';
import 'package:pokepod/domain/generations.dart';

AchievementInput input({
  int discovered = 0,
  int studied = 0,
  int mastered = 0,
  int favourites = 0,
  int largestCollection = 0,
  int collections = 0,
  int largestTeam = 0,
  int mysteryWins = 0,
  int bestStreak = 0,
  Set<int> discoveredIds = const {},
  int notes = 0,
}) => AchievementInput(
  discovered: discovered,
  studied: studied,
  mastered: mastered,
  favourites: favourites,
  largestCollection: largestCollection,
  collections: collections,
  largestTeam: largestTeam,
  mysteryWins: mysteryWins,
  bestStreak: bestStreak,
  discoveredIds: discoveredIds,
  notes: notes,
);

Achievement byId(List<Achievement> list, String id) =>
    list.firstWhere((a) => a.id == id, orElse: () => fail('missing $id'));

/// 0-255 channels of a [Color], avoiding the deprecated `.red`/`.green`/`.blue`
/// accessors.
List<int> _rgb(Color color) => [
  (color.r * 255).round(),
  (color.g * 255).round(),
  (color.b * 255).round(),
];

void main() {
  final all = computeAchievements(input());

  group('catalogue', () {
    test('exactly 20 achievements with unique ids', () {
      expect(all, hasLength(20));
      expect(all.map((a) => a.id).toSet(), hasLength(20));
    });

    test('the twelve pre-existing achievements are unchanged', () {
      const expected = <(String, String, String, int)>[
        ('first_contact', 'First Contact', 'Discover your first Pokémon.', 1),
        ('field_researcher', 'Field Researcher', 'Discover 25 Pokémon.', 25),
        ('cataloguer', 'Cataloguer', 'Discover 100 Pokémon.', 100),
        (
          'kanto_complete',
          'Kanto Complete',
          'Discover all 151 Generation I Pokémon.',
          151,
        ),
        ('scholar', 'Scholar', 'Mark 10 Pokémon as Studied or Mastered.', 10),
        ('mastery', 'Mastery', 'Master a Pokémon.', 1),
        ('curator', 'Curator', 'Build a collection with 5 Pokémon.', 5),
        ('team_architect', 'Team Architect', 'Build a team of 6.', 6),
        (
          'first_solve',
          'Mystery Solved',
          'Solve Who\'s That Pokémon? once.',
          1,
        ),
        ('streak_3', 'On a Roll', 'Reach a best Mystery streak of 3.', 3),
        ('journalist', 'Field Notes', 'Write notes for 3 Pokémon.', 3),
        ('favourite_five', 'Favourites', 'Favourite 5 Pokémon.', 5),
      ];
      for (final (id, title, rule, target) in expected) {
        final a = byId(all, id);
        expect(a.title, title, reason: id);
        expect(a.rule, rule, reason: id);
        expect(a.target, target, reason: id);
      }
    });

    test('the eight new achievements exist with sensible rules', () {
      const expected = <(String, String, int)>[
        ('streak_10', 'Blaze Keeper', 10),
        ('streak_30', 'Month of Mysteries', 30),
        ('streak_60', 'Seasoned Sleuth', 60),
        ('streak_100', 'Hundred-Day Hero', 100),
        ('streak_150', 'Shadow Master', 150),
        ('streak_365', 'A Year Unbroken', 365),
        ('mystery_50', 'Dedicated Challenger', 50),
        ('world_tour', 'World Tour', 9),
      ];
      for (final (id, title, target) in expected) {
        final a = byId(all, id);
        expect(a.title, title, reason: id);
        expect(a.target, target, reason: id);
        expect(a.rule, isNotEmpty, reason: id);
      }
    });
  });

  group('rarity tiers', () {
    test('exactly nine tiers exist', () {
      expect(AchievementRarity.values, hasLength(9));
      expect(
        AchievementRarity.values.map((r) => r.label).toSet(),
        hasLength(9),
      );
    });

    test('every tier has a clearly distinguishable colour', () {
      expect(kRarityColors.keys.toSet(), AchievementRarity.values.toSet());
      final colors = kRarityColors.values.toSet();
      expect(colors, hasLength(9), reason: 'rarity colours must be unique');
      // No two colours may be nearly identical (ΔE-ish check on RGB space).
      final list = colors.toList();
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          final a = list[i];
          final b = list[j];
          final ca = _rgb(a);
          final cb = _rgb(b);
          final dist =
              ((ca[0] - cb[0]) * (ca[0] - cb[0])) +
              ((ca[1] - cb[1]) * (ca[1] - cb[1])) +
              ((ca[2] - cb[2]) * (ca[2] - cb[2]));
          expect(
            dist,
            greaterThan(1200),
            reason: '${a.toARGB32()} and ${b.toARGB32()} are too similar',
          );
        }
      }
    });

    test('Rare is yellow/gold and Epic is purple', () {
      final rare = _rgb(kRarityColors[AchievementRarity.rare]!);
      expect(rare[0], greaterThanOrEqualTo(220));
      expect(rare[1], greaterThanOrEqualTo(180));
      expect(rare[2], lessThan(120));

      final epic = _rgb(kRarityColors[AchievementRarity.epic]!);
      expect(epic[2], greaterThan(200));
      expect(epic[0], inInclusiveRange(120, 200));
      expect(epic[1], lessThan(180));
      expect(epic[1], lessThan(epic[2]));
    });

    test(
      'rarity-to-colour mapping is centralised and readable in both themes',
      () {
        // The mapping covers every tier and the label variant darkens in light
        // theme for readability, without changing the accent colour.
        for (final rarity in AchievementRarity.values) {
          final dark = rarityLabelColor(rarity, Brightness.dark);
          final light = rarityLabelColor(rarity, Brightness.light);
          expect(dark, kRarityColors[rarity]);
          expect(
            light.toARGB32(),
            isNot(dark.toARGB32()),
            reason: '${rarity.label} label should darken on light surfaces',
          );
        }
      },
    );

    test('Hyper Rare is legendary gold, deeper than plain Rare', () {
      final hyper = _rgb(kRarityColors[AchievementRarity.hyperRare]!);
      final rare = _rgb(kRarityColors[AchievementRarity.rare]!);

      // Same warm family, unmistakable weight difference: Rare is a bright
      // yellow-gold, Hyper Rare is a deep royal gold that leads with red.
      expect(hyper[0], greaterThan(hyper[1]), reason: 'gold leads with red');
      expect(hyper[1], greaterThan(hyper[2]));
      expect(
        hyper[0] + hyper[1] + hyper[2],
        lessThan(rare[0] + rare[1] + rare[2]),
        reason: 'the legendary tier must read deeper, not brighter',
      );
      expect(
        rarityLabelColor(
          AchievementRarity.hyperRare,
          Brightness.dark,
        ).computeLuminance(),
        lessThan(
          rarityLabelColor(
            AchievementRarity.rare,
            Brightness.dark,
          ).computeLuminance(),
        ),
      );
    });

    test('only Hyper Rare carries the metallic ramp', () {
      for (final rarity in AchievementRarity.values) {
        final isHyper = rarity == AchievementRarity.hyperRare;
        expect(
          rarityFillGradient(rarity) != null,
          isHyper,
          reason: '${rarity.label} sheen',
        );
        expect(rarityGradient(rarity, Brightness.dark) != null, isHyper);
        expect(rarityGradient(rarity, Brightness.light) != null, isHyper);
      }
      // The label ramp follows the surface; the filled ramp always reads as
      // gold because it sits behind an icon.
      expect(
        rarityGradient(AchievementRarity.hyperRare, Brightness.light)!.colors,
        kHyperRareGoldOnLight,
      );
      expect(
        rarityGradient(AchievementRarity.hyperRare, Brightness.dark)!.colors,
        kHyperRareGold,
      );
      expect(
        rarityFillGradient(AchievementRarity.hyperRare)!.colors,
        kHyperRareGold,
      );
    });

    test('the gold ramp is warm and brightens towards the highlight', () {
      for (final ramp in [kHyperRareGold, kHyperRareGoldOnLight]) {
        expect(ramp, hasLength(3));
        for (final stop in ramp) {
          final c = _rgb(stop);
          expect(c[0], greaterThan(c[1]), reason: 'warm gold: red leads');
          expect(c[1], greaterThan(c[2]), reason: 'warm gold: green follows');
          expect(
            c[0] - c[2],
            greaterThan(20),
            reason: 'always warm metal, never a cool or neon tint',
          );
        }
        for (var i = 1; i < ramp.length; i++) {
          expect(
            ramp[i].computeLuminance(),
            greaterThan(ramp[i - 1].computeLuminance()),
            reason: 'the sheen brightens with every stop',
          );
        }
      }
    });

    test('the gold clears readable contrast on both surfaces', () {
      // Light theme: "HYPER RARE" is painted with the on-light ramp over
      // white paper — even its lightest stop must clear 4.5:1.
      const white = 1.0;
      for (final stop in kHyperRareGoldOnLight) {
        final ratio = (white + 0.05) / (stop.computeLuminance() + 0.05);
        expect(ratio, greaterThan(4.5), reason: 'on-light stop too faint');
      }
      // Dark theme: the bright ramp over the app's dark surface.
      const surface = Color(0xFF10161C);
      for (final stop in kHyperRareGold) {
        final ratio =
            (stop.computeLuminance() + 0.05) /
            (surface.computeLuminance() + 0.05);
        expect(ratio, greaterThan(4.5), reason: 'on-dark stop too dim');
      }
    });
  });

  group('RarityLabel', () {
    Future<void> pumpLabel(
      WidgetTester tester,
      AchievementRarity rarity,
      Brightness brightness,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.dark
              ? ThemeData.dark()
              : ThemeData.light(),
          home: Scaffold(body: RarityLabel(rarity: rarity, uppercase: true)),
        ),
      );
    }

    testWidgets('only the top tier is painted with the sheen', (tester) async {
      for (final brightness in Brightness.values) {
        for (final rarity in AchievementRarity.values) {
          await pumpLabel(tester, rarity, brightness);

          expect(
            find.text(rarity.label.toUpperCase()),
            findsOneWidget,
            reason: '${rarity.label} must still read as text',
          );
          expect(
            find.byType(ShaderMask),
            rarity == AchievementRarity.hyperRare
                ? findsOneWidget
                : findsNothing,
            reason: '${rarity.label} keeps its flat colour unless legendary',
          );
        }
      }
    });

    testWidgets('the other tiers keep their readable flat label', (
      tester,
    ) async {
      await pumpLabel(tester, AchievementRarity.rare, Brightness.light);

      final label = tester.widget<Text>(find.text('RARE'));
      expect(
        label.style?.color,
        rarityLabelColor(AchievementRarity.rare, Brightness.light),
      );
    });

    testWidgets('the sheen is a gradient mask over white text', (tester) async {
      await pumpLabel(tester, AchievementRarity.hyperRare, Brightness.dark);

      final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
      expect(mask.blendMode, BlendMode.srcIn);
      final child = mask.child as Text;
      expect(child.style?.color, const Color(0xFFFFFFFF));
    });
  });

  group('rarity assignment', () {
    test('assignments reflect difficulty, not recency', () {
      const expected = <String, AchievementRarity>{
        'first_contact': AchievementRarity.common,
        'mastery': AchievementRarity.common,
        'first_solve': AchievementRarity.common,
        'streak_3': AchievementRarity.common,
        'journalist': AchievementRarity.common,
        'field_researcher': AchievementRarity.uncommon,
        'scholar': AchievementRarity.uncommon,
        'curator': AchievementRarity.uncommon,
        'team_architect': AchievementRarity.uncommon,
        'favourite_five': AchievementRarity.uncommon,
        'cataloguer': AchievementRarity.rare,
        'world_tour': AchievementRarity.rare,
        'streak_10': AchievementRarity.rare,
        'streak_30': AchievementRarity.epic,
        'mystery_50': AchievementRarity.epic,
        'streak_60': AchievementRarity.doubleRare,
        'streak_100': AchievementRarity.ultraRare,
        'streak_150': AchievementRarity.illustrationRare,
        'kanto_complete': AchievementRarity.specialIllustrationRare,
        'streak_365': AchievementRarity.hyperRare,
      };
      for (final e in expected.entries) {
        expect(byId(all, e.key).rarity, e.value, reason: e.key);
      }
    });

    test('the 365-day streak is Hyper Rare, the highest tier', () {
      expect(byId(all, 'streak_365').rarity, AchievementRarity.hyperRare);
      expect(AchievementRarity.values.last, AchievementRarity.hyperRare);
    });
  });

  group('mystery streak milestones', () {
    for (final (id, target) in [
      ('streak_10', 10),
      ('streak_30', 30),
      ('streak_60', 60),
      ('streak_100', 100),
      ('streak_150', 150),
      ('streak_365', 365),
    ]) {
      test('$id unlocks exactly at $target and not below', () {
        final below = byId(
          computeAchievements(input(bestStreak: target - 1)),
          id,
        );
        expect(below.unlocked, isFalse);
        expect(below.progress, target - 1);

        final at = byId(computeAchievements(input(bestStreak: target)), id);
        expect(at.unlocked, isTrue);
        expect(at.progress, target);
      });

      test('$id counts the streak, never games played', () {
        // Many wins but a short streak must not unlock a streak milestone.
        final a = byId(
          computeAchievements(input(mysteryWins: 500, bestStreak: 2)),
          id,
        );
        expect(a.unlocked, isFalse);
        expect(a.progress, 2);
      });
    }

    test('progress is clamped to the target once earned', () {
      final a = byId(computeAchievements(input(bestStreak: 999)), 'streak_365');
      expect(a.progress, 365);
      expect(a.fraction, 1);
    });
  });

  group('additional achievements', () {
    test('world_tour requires a discovery from every generation', () {
      // One representative id from each generation range (first 8, then all 9).
      int idOf(int gen) => kGenerationRanges[gen - 1].$1;
      final eight = byId(
        computeAchievements(
          input(discoveredIds: {for (var g = 1; g <= 8; g++) idOf(g)}),
        ),
        'world_tour',
      );
      expect(eight.progress, 8);
      expect(eight.unlocked, isFalse);

      final nine = byId(
        computeAchievements(
          input(discoveredIds: {for (var g = 1; g <= 9; g++) idOf(g)}),
        ),
        'world_tour',
      );
      expect(nine.progress, 9);
      expect(nine.unlocked, isTrue);
    });

    test('mystery_50 unlocks at 50 wins and not below', () {
      final below = byId(
        computeAchievements(input(mysteryWins: 49)),
        'mystery_50',
      );
      expect(below.unlocked, isFalse);

      final at = byId(
        computeAchievements(input(mysteryWins: 50)),
        'mystery_50',
      );
      expect(at.unlocked, isTrue);
    });
  });

  group('unlock safety', () {
    test('existing achievements are preserved when new ones unlock', () {
      final list = computeAchievements(
        input(
          discovered: 1025,
          studied: 100,
          mastered: 50,
          favourites: 100,
          largestCollection: 100,
          collections: 10,
          largestTeam: 6,
          mysteryWins: 200,
          bestStreak: 400,
          discoveredIds: {for (var id = 1; id <= 1025; id++) id},
          notes: 50,
        ),
      );
      expect(list.every((a) => a.unlocked), isTrue);
      expect(list.where((a) => a.unlocked), hasLength(20));
    });

    test('unlock state is a pure function of progress (restart-safe)', () {
      final a = computeAchievements(input(bestStreak: 12));
      final b = computeAchievements(input(bestStreak: 12));
      expect(
        a.map((x) => (x.id, x.progress, x.target, x.unlocked)).toList(),
        b.map((x) => (x.id, x.progress, x.target, x.unlocked)).toList(),
      );
    });
  });
}
