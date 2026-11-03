import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/sound_service.dart';
import '../core/storage/local_store.dart';
import '../data/providers.dart';
import '../domain/mystery_logic.dart';
import 'focus_policy.dart';
import '../features/analysis/lab_page.dart';
import '../features/collections/collections_page.dart';
import '../features/discover/discover_page.dart';
import '../features/mystery/mystery_controller.dart';
import '../features/mystery/mystery_page.dart';
import '../features/notifications/notification_onboarding.dart';
import '../features/notifications/notification_service.dart';
import '../features/notifications/notifications_controller.dart';
import '../features/pokedex/pokedex_page.dart';
import '../features/pokemon_detail/dossier_page.dart';
import '../features/trainer_profile/achievement_unlocks.dart';
import '../features/trainer_profile/profile_controller.dart';
import '../features/trainer_profile/profile_page.dart';
import '../features/widgets/specimen_widget_sync.dart';
import 'theme/tokens.dart';

/// Index of the selected primary destination. It is the single source of truth:
/// the bottom bar, swipes and in-app shortcuts all read and write it.
final navIndexProvider = StateProvider<int>((ref) => 0);

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  late final PageController _pages = PageController(
    initialPage: ref.read(navIndexProvider),
  );
  Timer? _midnight;

  /// Guards the one-time notification bootstrap (permission state, launch
  /// details, first-install explanation, first reminder arm).
  bool _notificationsReady = false;

  /// Guards against opening Who's That Pokémon? twice from notification taps.
  bool _mysteryRouteOpen = false;

  /// Guards against opening the specimen dossier twice from widget taps.
  bool _specimenRouteOpen = false;

  /// Diff-and-queue tracker for achievement unlock notifications.
  final _unlocks = AchievementUnlocks();

  /// Native channel: widget taps deliver a route name here (MainActivity
  /// holds it until Dart asks, so cold-start taps are not lost).
  static const MethodChannel _routeChannel = MethodChannel('pokepod/routes');

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.explore_outlined),
      selectedIcon: Icon(Icons.explore),
      label: 'Discover',
    ),
    NavigationDestination(
      icon: Icon(Icons.grid_view_outlined),
      selectedIcon: Icon(Icons.grid_view_rounded),
      label: 'Pokédex',
    ),
    NavigationDestination(
      icon: Icon(Icons.science_outlined),
      selectedIcon: Icon(Icons.science),
      label: 'Lab',
    ),
    NavigationDestination(
      icon: Icon(Icons.collections_bookmark_outlined),
      selectedIcon: Icon(Icons.collections_bookmark),
      label: 'Collections',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initRoutes());
      unawaited(_bootstrapNotifications());
      unawaited(ref.read(specimenWidgetProvider.notifier).refresh());
    });
  }

  /// Listens for widget taps (foreground and cold start) and opens today's
  /// Specimen of the Day. On platforms without the native channel the
  /// MissingPluginException is simply ignored.
  Future<void> _initRoutes() async {
    try {
      _routeChannel.setMethodCallHandler((call) async {
        if (call.method == 'openRoute') {
          await _handleSpecimenRoute(call.arguments as String?);
        }
      });
      final pending = await _routeChannel.invokeMethod<String>(
        'getPendingRoute',
      );
      await _handleSpecimenRoute(pending);
    } catch (_) {
      // Desktop, tests or a host without the channel: no widget taps exist.
    }
  }

  /// Opens the dossier of the current Specimen of the Day, exactly once per
  /// tap, from the same selection the widget and Discover display.
  Future<void> _handleSpecimenRoute(String? route) async {
    if (!mounted || route != 'specimen' || _specimenRouteOpen) {
      return;
    }
    _specimenRouteOpen = true;
    ref.read(navIndexProvider.notifier).state = 0;
    final id = specimenOfDayId(ref.read(todayKeyProvider));
    try {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => DossierPage(id: id)));
    } finally {
      _specimenRouteOpen = false;
    }
  }

  /// One-time notification setup, deliberately after the first frame so it
  /// never delays startup: tap handling, the first-install explanation for
  /// brand-new installs only, and the first reminder evaluation.
  Future<void> _bootstrapNotifications() async {
    if (_notificationsReady) {
      return;
    }
    _notificationsReady = true;
    final service = ref.read(notificationServiceProvider);
    service.onOpened = (payload) {
      if (payload == kReminderPayloadMystery) {
        unawaited(_openMysteryFromReminder());
      }
    };
    await service.init();
    // A launch straight from a tapped reminder must land in the game.
    final details = await service.launchDetails();
    if (details?.didNotificationLaunchApp == true &&
        details?.notificationResponse?.payload == kReminderPayloadMystery) {
      await _openMysteryFromReminder();
    }
    if (!mounted) {
      return;
    }
    final prefs = ref.read(notificationsPrefsProvider);
    final store = ref.read(sharedPreferencesProvider);
    if (notificationsSupported &&
        shouldShowNotificationOnboarding(store, prefs)) {
      await showNotificationOnboarding(context, ref);
    }
    if (!mounted) {
      return;
    }
    await refreshStreakReminder(ProviderScope.containerOf(context));
  }

  /// Opens Who's That Pokémon? for a reminder tap, exactly once.
  Future<void> _openMysteryFromReminder() async {
    if (!mounted || _mysteryRouteOpen) {
      return;
    }
    _mysteryRouteOpen = true;
    ref.read(navIndexProvider.notifier).state = 0;
    try {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const MysteryPage()));
    } finally {
      _mysteryRouteOpen = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Short effects should not keep playing after the app is left.
      unawaited(ref.read(soundServiceProvider).stopAll());
    }
    if (state == AppLifecycleState.resumed) {
      // The app was in the background: the date (and daily Pokémon) may have changed.
      _refreshDay();
      _scheduleMidnight();
    }
  }

  void _refreshDay() {
    ref.read(dayTickProvider.notifier).state++;
  }

  /// Re-reads the date at the next local midnight while the app stays open.
  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = ref.read(clockProvider)();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        _refreshDay();
        _scheduleMidnight();
      },
    );
  }

  /// Shows a queued achievement unlock once the current frame is done, so a
  /// change that arrives while the tree is building never mutates the
  /// messenger mid-build. The frame is requested explicitly because the
  /// provider change alone does not always schedule one.
  void _scheduleUnlockDisplay() {
    if (!_unlocks.hasPending) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _unlocks.showNext(messenger);
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Widget _page(int i) {
    switch (i) {
      case 0:
        return const DiscoverPage();
      case 1:
        return const PokedexPage();
      case 2:
        return const LabPage();
      case 3:
        return const CollectionsPage();
      default:
        return const ProfilePage();
    }
  }

  /// Moves the pager to [index] when the selection changed from somewhere
  /// other than a swipe (bottom bar tap, shortcut, system back).
  void _syncPager(int index) {
    if (!_pages.hasClients) {
      return;
    }
    final current = _pages.page?.round() ?? index;
    if (current == index) {
      return;
    }
    if ((current - index).abs() > 1) {
      // Jumping avoids building and flashing every page in between.
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(index, duration: Motion.medium, curve: Motion.curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(navIndexProvider);
    ref.listen<int>(navIndexProvider, (previous, next) {
      _syncPager(next);
      // The tabs are kept alive by the PageView, so a focused field on the
      // leaving tab would otherwise carry its keyboard into the destination
      // tab (Discover has no text input of its own). Releasing focus here
      // dismisses the keyboard exactly when the section changes.
      if (previous != next) {
        releaseTextFocus();
      }
    });
    // Any change to the game state, the day or the notification choices can
    // make the pending streak reminder relevant or obsolete.
    final container = ProviderScope.containerOf(context);
    ref.listen(
      mysteryProvider,
      (_, _) => unawaited(refreshStreakReminder(container)),
    );
    ref.listen(
      notificationsPrefsProvider,
      (_, _) => unawaited(refreshStreakReminder(container)),
    );
    ref.listen(dayTickProvider, (_, _) {
      unawaited(refreshStreakReminder(container));
      // The daily specimen may have rolled over: refresh the widgets too.
      unawaited(ref.read(specimenWidgetProvider.notifier).refresh());
    });
    // The widget shows the specimen's name and types as soon as the app has
    // them (from cache or network), and the artwork on first availability.
    ref.listen(catalogProvider, (_, next) {
      if (!next.isLoading) {
        unawaited(ref.read(specimenWidgetProvider.notifier).refresh());
      }
    });
    final today = ref.watch(todayKeyProvider);
    final specimenId = specimenOfDayId(today);
    ref.listen(pokemonDetailProvider(specimenId), (_, next) {
      if (!next.isLoading) {
        unawaited(ref.read(specimenWidgetProvider.notifier).refresh());
      }
    });
    // Achievement unlocks. Every input is read synchronously from prefs by
    // the notifiers behind achievementsProvider, so the first observation is
    // the final baseline for this run: anything already unlocked is never
    // announced. Later changes are diffed and only real locked → unlocked
    // transitions are queued, one notification at a time.
    if (_unlocks.observe(ref.read(achievementsProvider)).isNotEmpty) {
      _scheduleUnlockDisplay();
    }
    ref.listen(achievementsProvider, (_, next) {
      if (_unlocks.observe(next).isNotEmpty) {
        _scheduleUnlockDisplay();
      }
    });

    // Back from any tab other than Discover returns to Discover first.
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ref.read(navIndexProvider.notifier).state = 0;
        }
      },
      child: Scaffold(
        body: PageView.builder(
          controller: _pages,
          itemCount: _destinations.length,
          // Swipes update the same provider the bottom bar uses.
          onPageChanged: (i) => ref.read(navIndexProvider.notifier).state = i,
          itemBuilder: (context, i) => _KeepAlive(child: _page(i)),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) =>
              ref.read(navIndexProvider.notifier).state = i,
          destinations: _destinations,
        ),
      ),
    );
  }
}

/// Keeps a tab's state (scroll position, filters, text) alive while it is
/// off-screen. Each page is created once, the first time it is shown.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
