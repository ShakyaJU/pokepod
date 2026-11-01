import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/sound_service.dart';
import '../../core/storage/local_store.dart';
import '../../core/utils/formatters.dart';
import '../../domain/mystery_logic.dart';

/// The device clock. Overridable in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Bumped when the app resumes or local midnight passes, so the date below is
/// re-read without restarting the app.
final dayTickProvider = StateProvider<int>((ref) => 0);

/// Today's date on the device (local calendar day). Overridable in tests.
final todayKeyProvider = Provider<String>((ref) {
  ref.watch(dayTickProvider);
  return localDateKey(ref.watch(clockProvider)());
});

enum GuessResult { ignored, wrong, won, lost }

/// Saved state of "Who's That Pokémon?".
///
/// * [history]: finished days (won or lost), each with the answer it had.
/// * [activeDate] / [activeTarget] / [guesses]: the day currently being played.
///   The answer is stored the first time a day is opened and never recomputed.
/// * [lastSeen]: the latest day the game was opened, used so turning the clock
///   back cannot reopen an earlier day.
class MysteryState {
  const MysteryState({
    this.history = const {},
    this.activeDate,
    this.activeTarget,
    this.guesses = const [],
    this.lastSeen,
  });

  final Map<String, MysteryRecord> history;
  final String? activeDate;
  final int? activeTarget;
  final List<int> guesses;
  final String? lastSeen;

  List<int> guessesFor(String day) => activeDate == day ? guesses : const [];
  bool completed(String day) => history.containsKey(day);

  ChallengeStatus statusFor(String day) {
    final record = history[day];
    if (record != null) {
      return record.won ? ChallengeStatus.won : ChallengeStatus.lost;
    }
    return guessesFor(day).isEmpty
        ? ChallengeStatus.ready
        : ChallengeStatus.inProgress;
  }

  int guessesLeft(String day) {
    if (completed(day)) {
      return 0;
    }
    return kMysteryMaxGuesses - guessesFor(day).length;
  }

  /// The answer for [day]: a saved answer wins; otherwise progress saved by an
  /// older version keeps the answer that version used; otherwise it is chosen
  /// fresh by the current selection.
  int targetFor(String day) {
    final record = history[day];
    if (record?.target != null) {
      return record!.target!;
    }
    if (activeDate == day && activeTarget != null) {
      return activeTarget!;
    }
    if (record != null || (activeDate == day && guesses.isNotEmpty)) {
      return legacyMysteryAnswerId(day);
    }
    return mysteryAnswerId(day);
  }
}

class MysteryNotifier extends Notifier<MysteryState> {
  static const storageKey = 'mystery.v1';
  static const formatVersion = 2;

  @override
  MysteryState build() {
    final json = readJsonMap(ref.watch(sharedPreferencesProvider), storageKey);
    if (json == null) {
      return const MysteryState();
    }
    final history = <String, MysteryRecord>{};
    final rawHistory = json['history'];
    if (rawHistory is Map<String, dynamic>) {
      rawHistory.forEach((k, v) {
        final record = MysteryRecord.tryFromJson(v);
        if (record != null && parseDateKey(k) != null) {
          history[k] = record;
        }
      });
    }
    final active = json['active'];
    final target = json['target'];
    final seen = json['seen'];
    final rawGuesses = json['guesses'];
    return MysteryState(
      history: history,
      activeDate: active is String ? active : null,
      activeTarget: target is int ? target : null,
      guesses: [
        for (final v
            in rawGuesses is List<dynamic> ? rawGuesses : const <dynamic>[])
          if (v is int) v,
      ],
      lastSeen: seen is String ? seen : null,
    );
  }

  /// Opens [day]: stores its answer the first time (so it can never be
  /// re-rolled) and moves the in-progress slot to it. Unfinished guesses from an
  /// earlier day are dropped; that day simply counts as not played.
  void ensureDay(String day) {
    if (state.lastSeen != null && day.compareTo(state.lastSeen!) < 0) {
      return; // the clock went backwards: never reopen an earlier day
    }
    final s = state;
    if (s.history.containsKey(day)) {
      if (s.lastSeen != day) {
        state = MysteryState(
          history: s.history,
          activeDate: s.activeDate,
          activeTarget: s.activeTarget,
          guesses: s.guesses,
          lastSeen: day,
        );
        _save();
      }
      return;
    }
    if (s.activeDate == day && s.activeTarget != null && s.lastSeen == day) {
      return;
    }
    final sameDay = s.activeDate == day;
    state = MysteryState(
      history: s.history,
      activeDate: day,
      activeTarget: sameDay
          ? (s.activeTarget ?? s.targetFor(day))
          : s.targetFor(day),
      guesses: sameDay ? s.guesses : const [],
      lastSeen: day,
    );
    _save();
  }

  /// Records a guess. A finished day, a repeated guess, an invalid Pokémon and a
  /// day before the latest one played are all ignored, so duplicate submissions
  /// can never double-count a win, a loss or a streak.
  GuessResult submitGuess(
    int guessId, {
    required int answerId,
    required String today,
  }) {
    if (guessId < 1 || guessId > kNationalDexSize) {
      return GuessResult.ignored;
    }
    if (state.lastSeen != null && today.compareTo(state.lastSeen!) < 0) {
      return GuessResult.ignored;
    }
    if (state.completed(today)) {
      return GuessResult.ignored;
    }
    final current = state.guessesFor(today);
    if (current.contains(guessId)) {
      return GuessResult.ignored;
    }

    final guesses = [...current, guessId];
    final history = Map<String, MysteryRecord>.from(state.history);
    var result = GuessResult.wrong;
    if (guessId == answerId) {
      history[today] = MysteryRecord(
        guesses: guesses.length,
        won: true,
        target: answerId,
      );
      result = GuessResult.won;
    } else if (guesses.length >= kMysteryMaxGuesses) {
      history[today] = MysteryRecord(
        guesses: guesses.length,
        won: false,
        target: answerId,
      );
      result = GuessResult.lost;
    }
    state = MysteryState(
      history: history,
      activeDate: today,
      activeTarget: answerId,
      guesses: guesses,
      lastSeen: today,
    );
    _save();
    // Exactly one effect per accepted guess, chosen from the result just determined.
    // Ignored guesses returned earlier, so they never reach this point.
    unawaited(
      ref
          .read(soundServiceProvider)
          .play(result == GuessResult.won ? Sfx.correct : Sfx.error),
    );
    return result;
  }

  void _save() {
    ref
        .read(sharedPreferencesProvider)
        .setString(
          storageKey,
          jsonEncode({
            'v': formatVersion,
            'history': {
              for (final e in state.history.entries) e.key: e.value.toJson(),
            },
            'active': state.activeDate,
            'target': state.activeTarget,
            'guesses': state.guesses,
            'seen': state.lastSeen,
          }),
        );
  }
}

final mysteryProvider = NotifierProvider<MysteryNotifier, MysteryState>(
  MysteryNotifier.new,
);

/// The day the game is on: today, unless the device clock was turned back past
/// a day that has already been opened.
final challengeDayProvider = Provider<String>((ref) {
  final today = ref.watch(todayKeyProvider);
  final seen = ref.watch(mysteryProvider.select((s) => s.lastSeen));
  return seen != null && seen.compareTo(today) > 0 ? seen : today;
});

/// Today's answer.
final challengeTargetProvider = Provider<int>((ref) {
  final day = ref.watch(challengeDayProvider);
  return ref.watch(mysteryProvider).targetFor(day);
});

final mysteryStreaksProvider = Provider<MysteryStreaks>((ref) {
  final state = ref.watch(mysteryProvider);
  return calculateStreaks(state.history, ref.watch(challengeDayProvider));
});
