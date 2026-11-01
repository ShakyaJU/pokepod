import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/app/design_system/expandable_section.dart';
import 'package:pokepod/app/design_system/meta_badge.dart';
import 'package:pokepod/app/design_system/stat_readout.dart';
import 'package:pokepod/app/design_system/widgets.dart';
import 'package:pokepod/app/theme/app_theme.dart';
import 'package:pokepod/app/theme/system_ui.dart';
import 'package:pokepod/app/theme/tokens.dart';
import 'package:pokepod/core/storage/local_store.dart';
import 'package:pokepod/data/providers.dart';
import 'package:pokepod/features/collections/collections_page.dart';
import 'package:pokepod/features/discover/discover_page.dart';
import 'package:pokepod/features/help/help_page.dart';
import 'package:pokepod/features/mystery/mystery_controller.dart';
import 'package:pokepod/features/trainer_profile/about_page.dart';
import 'package:pokepod/features/trainer_profile/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/support.dart';

Widget _host(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.build(Brightness.dark, AppColors.emerald),
      home: Scaffold(body: child),
    ),
  );
}

/// Routes, dialogs and AnimationControllers start on the first frame after a tap,
/// so one plain pump is needed before time can be advanced.
Future<void> _settle(WidgetTester tester, [int milliseconds = 500]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: milliseconds));
}

Future<void> _bigView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<List<Override>> _profileOverrides() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    apiClientProvider.overrideWithValue(
      FakeApiClient({
        '$apiBase/pokemon?limit=1025&offset=0': catalogJson([
          (1, 'bulbasaur'),
          (25, 'pikachu'),
        ]),
      }),
    ),
    imageProviderFactoryProvider.overrideWithValue(
      (url) => MemoryImage(_pixel),
    ),
  ];
}

final _pixel = Uri.parse(
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
).data!.contentAsBytes();

void main() {
  group('ExpandableSection', () {
    testWidgets('expands and collapses on repeated taps', (tester) async {
      await tester.pumpWidget(
        _host(
          const ExpandableSection(
            title: 'Research by type',
            child: Text('Body content'),
          ),
        ),
      );
      expect(find.text('Body content'), findsNothing);

      Future<double> chevronTurns() async => tester
          .widget<RotationTransition>(
            find.byKey(const ValueKey('expandable-chevron')),
          )
          .turns
          .value;

      expect(await chevronTurns(), 0);

      await tester.tap(find.text('Research by type'));
      await _settle(tester);
      expect(find.text('Body content'), findsOneWidget);
      expect(await chevronTurns(), 0.5);

      await tester.tap(find.text('Research by type'));
      await _settle(tester);
      expect(find.text('Body content'), findsNothing);
      expect(await chevronTurns(), 0);

      // Repeated taps keep working and never duplicate the content.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Research by type'));
        await _settle(tester);
        expect(find.text('Body content'), findsOneWidget);
        await tester.tap(find.text('Research by type'));
        await _settle(tester);
        expect(find.text('Body content'), findsNothing);
      }
    });

    testWidgets('does not build its body until opened', (tester) async {
      var built = 0;
      await tester.pumpWidget(
        _host(
          ExpandableSection(
            title: 'Lazy',
            child: Builder(
              builder: (context) {
                built++;
                return const Text('Lazy body');
              },
            ),
          ),
        ),
      );
      expect(built, 0);
      await tester.tap(find.text('Lazy'));
      await _settle(tester);
      expect(built, greaterThan(0));
    });

    testWidgets('can start expanded', (tester) async {
      await tester.pumpWidget(
        _host(
          const ExpandableSection(
            title: 'Open one',
            initiallyExpanded: true,
            child: Text('Shown'),
          ),
        ),
      );
      expect(find.text('Shown'), findsOneWidget);
      expect(
        tester
            .widget<RotationTransition>(
              find.byKey(const ValueKey('expandable-chevron')),
            )
            .turns
            .value,
        0.5,
      );
    });
  });

  group('MetaBadge', () {
    Future<List<double>> heights(
      WidgetTester tester, {
      double scale = 1,
    }) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: const Wrap(
                spacing: 8,
                children: [
                  MetaBadge(label: 'Normal', color: Colors.grey, dot: true),
                  MetaBadge(label: 'Generation IX', icon: Icons.public),
                  MetaBadge(
                    label: 'Legendary',
                    icon: Icons.workspace_premium,
                    color: AppColors.amber,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return [
        for (var i = 0; i < 3; i++)
          tester.getSize(find.byType(MetaBadge).at(i)).height,
      ];
    }

    testWidgets('badges of different labels and icons share one height', (
      tester,
    ) async {
      await _bigView(tester);
      final h = await heights(tester);
      expect(h.toSet(), hasLength(1));
      expect(h.first, greaterThanOrEqualTo(28));
    });

    testWidgets('heights stay equal at large text scales', (tester) async {
      await _bigView(tester);
      final h = await heights(tester, scale: 2);
      expect(h.toSet(), hasLength(1));
    });

    testWidgets('type chips use the same badge component', (tester) async {
      await tester.pumpWidget(
        _host(
          const Wrap(
            children: [TypeChip('normal'), TypeChip('fire', dense: true)],
          ),
        ),
      );
      expect(find.byType(MetaBadge), findsNWidgets(2));
      expect(find.text('Normal'), findsOneWidget);
    });
  });

  group('Profile menu', () {
    testWidgets('hamburger opens a menu with all five destinations', (
      tester,
    ) async {
      await _bigView(tester);
      await tester.pumpWidget(
        _host(const ProfilePage(), overrides: await _profileOverrides()),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byTooltip('Open profile menu'), findsOneWidget);
      await tester.tap(find.byTooltip('Open profile menu'));
      await _settle(tester);

      for (final key in [
        'achievements',
        'journal',
        'settings',
        'about',
        'help',
      ]) {
        expect(find.byKey(Key('menu-$key')), findsOneWidget, reason: key);
      }
      expect(find.byIcon(Icons.help_outline), findsWidgets);
    });

    testWidgets('the menu footer credits the creator, not a banner', (
      tester,
    ) async {
      await _bigView(tester);
      await tester.pumpWidget(
        _host(const ProfilePage(), overrides: await _profileOverrides()),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byTooltip('Open profile menu'));
      await _settle(tester);

      expect(find.text('© ShakyaJU'), findsOneWidget);
      expect(find.text('Unofficial fan project'), findsNothing);
    });

    testWidgets('Help & User Guide sits above About, and About is last', (
      tester,
    ) async {
      await _bigView(tester);
      await tester.pumpWidget(
        _host(const ProfilePage(), overrides: await _profileOverrides()),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byTooltip('Open profile menu'));
      await _settle(tester);

      double top(String name) =>
          tester.getTopLeft(find.byKey(Key('menu-$name'))).dy;
      expect(top('achievements'), lessThan(top('journal')));
      expect(top('journal'), lessThan(top('settings')));
      expect(top('settings'), lessThan(top('help')));
      expect(top('help'), lessThan(top('about')));
      for (final key in [
        'achievements',
        'journal',
        'settings',
        'help',
        'about',
      ]) {
        expect(
          find.byKey(Key('menu-$key')),
          findsOneWidget,
          reason: 'no duplicates: $key',
        );
      }
      expect(find.text('Help & User Guide'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('menu entries open their pages', (tester) async {
      await _bigView(tester);
      final expectations = {
        'achievements': 'Milestones from your research',
        'journal': 'Your journal is empty',
        'settings': 'Appearance'.toUpperCase(),
        'about': 'Beyond the Pokédex',
        'help': 'Table of contents',
      };
      for (final entry in expectations.entries) {
        await tester.pumpWidget(
          _host(const ProfilePage(), overrides: await _profileOverrides()),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.byTooltip('Open profile menu'));
        await _settle(tester);
        await tester.tap(find.byKey(Key('menu-${entry.key}')));
        await _settle(tester, 600);
        expect(
          find.textContaining(entry.value),
          findsWidgets,
          reason: entry.key,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('a new profile shows the first-use guidance', (tester) async {
      await _bigView(tester);
      await tester.pumpWidget(
        _host(const ProfilePage(), overrides: await _profileOverrides()),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Start your collection'), findsOneWidget);
      expect(find.text('Browse the Pokédex'), findsOneWidget);
    });
  });

  group('Help guide', () {
    testWidgets('search narrows the topics and expands the matches', (
      tester,
    ) async {
      await _bigView(tester);
      await tester.pumpWidget(_host(const HelpPage()));
      expect(find.text('Welcome to PokéPod'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'streak');
      await _settle(tester);
      expect(find.text('Welcome to PokéPod'), findsNothing);
      expect(find.text('Who\'s That Pokémon?'), findsOneWidget);
      expect(find.textContaining('adds to your streak'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzzzqq');
      await _settle(tester, 300);
      expect(find.text('Nothing found'), findsOneWidget);
    });
  });

  group('Profile key statistics', () {
    Future<List<Rect>> pumpStats(
      WidgetTester tester, {
      required double width,
      double scale = 1,
    }) async {
      tester.view.physicalSize = Size(width, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _profileOverrides(),
          child: MaterialApp(
            theme: AppTheme.build(Brightness.dark, AppColors.emerald),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(body: ProfilePage()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final readouts = find.byType(StatReadout);
      expect(readouts, findsNWidgets(4));
      expect(find.text('BEST STREAK'), findsOneWidget);
      return [for (var i = 0; i < 4; i++) tester.getRect(readouts.at(i))];
    }

    testWidgets('a phone-width screen gets a balanced two-by-two grid', (
      tester,
    ) async {
      final r = await pumpStats(tester, width: 360);
      expect(
        r.map((e) => e.size).toSet(),
        hasLength(1),
        reason: 'every tile content has the same size',
      );
      expect(r[0].top, r[1].top);
      expect(r[2].top, r[3].top);
      expect(
        r[2].top - r[0].bottom,
        greaterThanOrEqualTo(16),
        reason: 'rows are separated',
      );
      expect(r[0].left, r[2].left);
      expect(r[1].left, r[3].left);
      expect(
        r[1].left - r[0].right,
        greaterThanOrEqualTo(16),
        reason: 'Studied/Mastered and Favourites/Best streak do not touch',
      );
    });

    testWidgets('a wide screen shows four separate tiles in one row', (
      tester,
    ) async {
      final r = await pumpStats(tester, width: 900);
      expect(r.map((e) => e.top).toSet(), hasLength(1));
      expect(r.map((e) => e.size).toSet(), hasLength(1));
      for (var i = 1; i < 4; i++) {
        expect(
          r[i].left - r[i - 1].right,
          greaterThanOrEqualTo(16),
          reason: 'gap before tile $i',
        );
      }
    });

    testWidgets(
      'larger text keeps the layout aligned instead of squeezing four across',
      (tester) async {
        final r = await pumpStats(tester, width: 500, scale: 1.4);
        expect(r.map((e) => e.size).toSet(), hasLength(1));
        expect(r[0].top, r[1].top);
        expect(r[2].top, r[3].top);
        expect(
          r[2].top,
          greaterThan(r[0].bottom),
          reason: 'two rows at this size',
        );
      },
    );
  });

  group('Daily challenge card', () {
    Future<void> pumpDiscover(
      WidgetTester tester, {
      Map<String, Object> prefs = const {},
    }) async {
      await _bigView(tester);
      SharedPreferences.setMockInitialValues(prefs);
      final store = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        _host(
          const DiscoverPage(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(store),
            apiClientProvider.overrideWithValue(
              FakeApiClient({
                '$apiBase/pokemon?limit=1025&offset=0': catalogJson([
                  (1, 'bulbasaur'),
                ]),
              }),
            ),
            imageProviderFactoryProvider.overrideWithValue(
              (url) => MemoryImage(_pixel),
            ),
            todayKeyProvider.overrideWithValue('2026-10-21'),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets(
      'separates the specimen from a streak panel with a fire accent',
      (tester) async {
        await pumpDiscover(tester);
        expect(find.text('🔥'), findsOneWidget);
        expect(find.text('DAY STREAK'), findsOneWidget);
        expect(find.text('Best 0'), findsOneWidget);
        expect(find.text('Ready to play'), findsOneWidget);

        final specimenRight = tester
            .getTopRight(find.text('Who\'s That Pokémon?'))
            .dx;
        final streakLeft = tester.getTopLeft(find.text('DAY STREAK')).dx;
        expect(
          streakLeft - specimenRight,
          greaterThan(24),
          reason: 'clear gap between the two groups',
        );
      },
    );

    testWidgets('shows the real streak and solved status', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpDiscover(
        tester,
        prefs: {
          'mystery.v1':
              '{"history":{"2026-10-20":{"g":3,"w":true},"2026-10-21":{"g":2,"w":true}}}',
        },
      );
      expect(find.text('Solved in 2'), findsOneWidget);
      expect(find.text('Best 2'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Current streak: 2 days')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('Branding', () {
    testWidgets('the About page uses the supplied logo', (tester) async {
      await _bigView(tester);
      await tester.pumpWidget(_host(const AboutPage()));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName ==
                  'assets/branding/pokepod_logo.png',
        ),
        findsOneWidget,
      );
      expect(find.text('Beyond the Pokédex'), findsOneWidget);
    });

    testWidgets('the in-app open-source licence entry is gone', (tester) async {
      await _bigView(tester);
      await tester.pumpWidget(_host(const AboutPage()));
      // Walk to the bottom so the check covers the whole page, not just the
      // part that happens to be built.
      await tester.drag(find.byType(ListView), const Offset(0, -2500));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.textContaining('This notice does not grant any rights'),
        findsOneWidget,
        reason: 'reached the disclaimer at the end of the page',
      );
      expect(find.text('Open-source licences'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      // The franchise disclaimer itself is preserved.
      expect(
        find.textContaining('PokéPod is an unofficial fan project'),
        findsOneWidget,
      );
    });
  });

  group('Status bar area', () {
    testWidgets('the strip reserves the height but paints no line of its own', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(Brightness.light, AppColors.emerald),
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(top: 32)),
            child: const SystemUiScope(child: Text('content')),
          ),
        ),
      );

      final strip = tester.widget<SizedBox>(
        find.byKey(const Key('system-ui-status-strip')),
      );
      expect(strip.height, 32, reason: 'safe-area protection stays');
      expect(
        strip.child,
        isNull,
        reason: 'no border or band of its own may sit under the status bar',
      );
      expect(find.byType(Divider), findsNothing);
      expect(find.text('content'), findsOneWidget);
    });
  });

  group('Discover', () {
    testWidgets('has no redundant Search, Lab or Compare shortcut buttons', (
      tester,
    ) async {
      await _bigView(tester);
      SharedPreferences.setMockInitialValues({});
      final store = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        _host(
          const DiscoverPage(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(store),
            apiClientProvider.overrideWithValue(
              FakeApiClient({
                '$apiBase/pokemon?limit=1025&offset=0': catalogJson([
                  (1, 'bulbasaur'),
                ]),
              }),
            ),
            imageProviderFactoryProvider.overrideWithValue(
              (url) => MemoryImage(_pixel),
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Search'), findsNothing);
      expect(find.text('Lab'), findsNothing);
      expect(find.text('Compare'), findsNothing);
      expect(find.text('SPECIMEN OF THE DAY'), findsOneWidget);
      expect(find.text('Who\'s That Pokémon?'), findsOneWidget);
      // The challenge uses a plain "?" and not the Help icon.
      expect(find.text('?'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline), findsNothing);
    });
  });

  group('Generation Dex Progress', () {
    testWidgets(
      'the dropdown changes the shown progress without touching saved progress',
      (tester) async {
        await _bigView(tester);
        SharedPreferences.setMockInitialValues({
          'research.v1': '{"1":1,"4":2,"152":3}',
        });
        final store = await SharedPreferences.getInstance();
        await tester.pumpWidget(
          _host(
            const CollectionsPage(),
            overrides: [
              sharedPreferencesProvider.overrideWithValue(store),
              apiClientProvider.overrideWithValue(
                FakeApiClient({
                  '$apiBase/pokemon?limit=1025&offset=0': catalogJson([
                    (1, 'bulbasaur'),
                    (4, 'charmander'),
                  ]),
                }),
              ),
              imageProviderFactoryProvider.overrideWithValue(
                (url) => MemoryImage(_pixel),
              ),
            ],
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('GENERATION DEX PROGRESS'), findsOneWidget);
        expect(find.text('LIVING DEX BY GENERATION'), findsNothing);
        // Default: the first generation that is not complete, here Generation I.
        expect(find.text('Generation I · #0001–#0151'), findsOneWidget);
        expect(find.text('2 of 151 discovered'), findsOneWidget);
        expect(find.text('1 studied · 0 mastered'), findsOneWidget);

        await tester.tap(find.byType(DropdownButton<int>));
        await _settle(tester);
        await tester.tap(find.text('Generation II · #0152–#0251').last);
        await _settle(tester);

        expect(find.text('1 of 100 discovered'), findsOneWidget);
        expect(find.text('0 studied · 1 mastered'), findsNothing);
        expect(find.text('1 studied · 1 mastered'), findsOneWidget);

        // Saved progress is untouched.
        expect(store.getString('research.v1'), '{"1":1,"4":2,"152":3}');

        // Switching back restores the first generation's numbers.
        await tester.tap(find.byType(DropdownButton<int>));
        await _settle(tester);
        await tester.tap(find.text('Generation I · #0001–#0151').last);
        await _settle(tester);
        expect(find.text('2 of 151 discovered'), findsOneWidget);
      },
    );
  });
}
