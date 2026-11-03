import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/design_system/rarity_label.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/rarity.dart';
import '../../app/theme/tokens.dart';
import '../../domain/achievements.dart';
import 'achievements_page.dart';
import 'profile_controller.dart';

/// Announces achievement unlocks as they really happen.
///
/// Every input of [achievementsProvider] is read synchronously from
/// SharedPreferences by the notifiers that feed it, so the first observation
/// is the authoritative baseline: whatever is already unlocked at that point
/// was earned before this run and must never be announced, which keeps a
/// normal launch free of false positives. From then on each observation is
/// diffed against the previous one and only a real locked → unlocked
/// transition is queued, so the same unlock is never announced twice and a
/// re-locked badge only speaks again if it is genuinely earned again.
///
/// Unlocks are shown one at a time: the next one is handed to the app's root
/// [ScaffoldMessenger] only after the previous one's `closed` future
/// completes, so several badges earned by the same action line up instead of
/// overlapping, and none is lost or duplicated.
class AchievementUnlocks {
  /// Ids unlocked as of the last observation; null until the first one.
  Set<String>? _baseline;

  /// Unlocks waiting for their turn.
  final List<Achievement> _queue = [];

  /// Whether a notification is currently on screen.
  bool _showing = false;

  /// Whether anything is on screen or still waiting.
  bool get hasPending => _showing || _queue.isNotEmpty;

  /// Unlocks waiting behind the one on screen.
  int get queued => _queue.length;

  /// Records [achievements] as the current state and queues every achievement
  /// that was locked on the previous observation and is unlocked now.
  ///
  /// The first call only establishes the baseline and returns nothing.
  List<Achievement> observe(List<Achievement> achievements) {
    final unlocked = {
      for (final achievement in achievements)
        if (achievement.unlocked) achievement.id,
    };
    final previous = _baseline;
    _baseline = unlocked;
    if (previous == null) {
      return const [];
    }
    final fresh = [
      for (final achievement in achievements)
        if (achievement.unlocked && !previous.contains(achievement.id))
          achievement,
    ];
    _queue.addAll(fresh);
    return fresh;
  }

  /// Shows the next queued unlock on [messenger], or does nothing when one is
  /// already on screen or the queue is empty. When that snackbar closes — by
  /// timeout, swipe or interruption — the one behind it takes its turn.
  void showNext(ScaffoldMessengerState messenger) {
    if (_showing || _queue.isEmpty) {
      return;
    }
    final achievement = _queue.removeAt(0);
    _showing = true;
    final controller = messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: _UnlockSnack(achievement: achievement),
      ),
    );
    unawaited(
      controller.closed.then((_) {
        _showing = false;
        if (messenger.mounted && _queue.isNotEmpty) {
          showNext(messenger);
        }
      }),
    );
  }
}

/// The body of an unlock notification: the achievement's icon, what it took
/// to earn it, its title and its rarity — the same facts the achievement
/// sheet shows, painted with the existing rarity theme.
class _UnlockSnack extends StatelessWidget {
  const _UnlockSnack({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A snackbar sits on the inverse surface, i.e. the opposite brightness to
    // the theme, so rarity colours are resolved for the surface they are
    // actually painted on rather than for a card.
    final onInverse = scheme.brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    final color = rarityLabelColor(achievement.rarity, onInverse);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          achievementIcons[achievement.id] ?? Icons.emoji_events_outlined,
          size: 26,
          color: color,
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Achievement unlocked',
                style: readoutStyle(
                  context,
                  size: 10,
                  color: scheme.onInverseSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                achievement.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: scheme.onInverseSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                achievement.rule,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: scheme.onInverseSurface.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: Space.sm),
              // The rarity caption is tuned for card surfaces, so it sits on a
              // neutral chip: that keeps its contrast correct whatever the
              // theme does to the snackbar behind it.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: RarityLabel(
                  rarity: achievement.rarity,
                  size: 10,
                  uppercase: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
