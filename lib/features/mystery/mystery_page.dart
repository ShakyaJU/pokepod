import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/widgets.dart';
import '../../core/audio/sound_service.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/pokemon.dart';
import '../../data/providers.dart';
import '../../domain/generations.dart';
import '../../domain/mystery_logic.dart';
import '../shared/navigation.dart';
import '../shared/pokemon_picker.dart';
import 'mystery_controller.dart';
import 'mystery_history.dart';
import 'reveal.dart';

/// Daily guessing game. One answer per local calendar day, chosen once, saved
/// the first time the day is opened and never re-rolled.
class MysteryPage extends ConsumerStatefulWidget {
  const MysteryPage({super.key});

  @override
  ConsumerState<MysteryPage> createState() => _MysteryPageState();
}

class _MysteryPageState extends ConsumerState<MysteryPage> {
  /// The audio service, captured while `ref` is certainly valid, so cleanup
  /// in [dispose] never touches the widget ref after teardown begins.
  late final SoundService _sound;

  @override
  void initState() {
    super.initState();
    _sound = ref.read(soundServiceProvider);
    Future<void>.microtask(() {
      if (mounted) {
        ref
            .read(mysteryProvider.notifier)
            .ensureDay(ref.read(challengeDayProvider));
        // initState runs once per entry, so rebuilds never replay it.
        unawaited(_sound.play(Sfx.game));
      }
    });
  }

  /// The entry sound belongs to this screen: silence it as soon as the route
  /// pops (back button, swipe-back, system back), even mid-playback. Only this
  /// effect is stopped — correct/wrong guess sounds run on their own players
  /// and are untouched. SoundService also skips the platform call entirely
  /// when the sound has already finished.
  void _stopEntrySound() {
    unawaited(_sound.stop(Sfx.game));
  }

  @override
  void dispose() {
    // Backstop for exits that are not pops (for example the route being
    // replaced): the screen is going away either way, and stopping a sound
    // that already ended is a no-op.
    _stopEntrySound();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A new day (midnight passed, or the app came back to the foreground).
    ref.listen<String>(
      challengeDayProvider,
      (previous, next) => ref.read(mysteryProvider.notifier).ensureDay(next),
    );
    final today = ref.watch(challengeDayProvider);
    final state = ref.watch(mysteryProvider);
    final answerId = state.targetFor(today);
    final streaks = ref.watch(mysteryStreaksProvider);
    final detail = ref.watch(pokemonDetailProvider(answerId));
    final species = ref.watch(speciesProvider(answerId));
    final scheme = Theme.of(context).colorScheme;

    final guesses = state.guessesFor(today);
    final completed = state.completed(today);
    final left = state.guessesLeft(today);
    final record = state.history[today];
    final revealed = completed
        ? kMysteryMaxGuesses
        : (guesses.length + 1).clamp(1, kMysteryMaxGuesses);
    final names = ref.watch(catalogByIdProvider);

    return PopScope(
      // Popping this route is always allowed; the callback fires the moment a
      // pop is committed (back button, swipe-back or system back).
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _stopEntrySound();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('Who\'s That Pokémon?'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Space.md),
          children: [
            Row(
              children: [
                Expanded(child: Text(today, style: readoutStyle(context))),
                Text(
                  completed
                      ? 'COMPLETE'
                      : '$left ${left == 1 ? 'GUESS' : 'GUESSES'} LEFT',
                  style: readoutStyle(context, color: scheme.primary),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            MysteryReveal(
              answerId: answerId,
              guessesMade: guesses.length,
              completed: completed,
            ),
            const SizedBox(height: Space.md),
            if (completed && record != null)
              Panel(
                borderColor: record.won ? scheme.primary : scheme.error,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.won
                          ? 'Solved in ${record.guesses} ${record.guesses == 1 ? 'guess' : 'guesses'}!'
                          : 'Game over',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.won
                          ? 'Today\'s Pokémon was ${detail.valueOrNull?.displayName ?? dexNumber(answerId)}.'
                          : 'You used all $kMysteryMaxGuesses guesses. Today\'s Pokémon was '
                                '${detail.valueOrNull?.displayName ?? dexNumber(answerId)}.',
                    ),
                    const SizedBox(height: Space.sm),
                    OutlinedButton(
                      onPressed: () => openDossier(context, answerId),
                      child: const Text('Open dossier'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.won
                          ? 'Your streak is updated. A new Pokémon arrives at midnight (your local time).'
                          : 'This day is finished and your streak has ended. A new Pokémon arrives at midnight (your local time).',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            if (!completed) ...[
              detail.when(
                loading: () => const SkeletonBox(height: 120),
                error: (e, _) => ErrorRetry(
                  error: e,
                  onRetry: () {
                    ref.invalidate(pokemonDetailProvider(answerId));
                    ref.invalidate(speciesProvider(answerId));
                  },
                ),
                data: (d) =>
                    _Clues(detail: d, species: species, revealed: revealed),
              ),
              const SizedBox(height: Space.md),
              if (guesses.isNotEmpty) ...[
                const SectionLabel('Your guesses'),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final g in guesses)
                      Chip(
                        avatar: PokemonArtwork(id: g, size: 24),
                        label: Text(names[g]?.displayName ?? dexNumber(g)),
                      ),
                  ],
                ),
                const SizedBox(height: Space.md),
              ],
              FilledButton.icon(
                onPressed: detail.hasValue
                    ? () async {
                        final picked = await showPokemonPicker(
                          context,
                          title: 'Who is it?',
                          excluded: guesses.toSet(),
                        );
                        if (picked == null || !context.mounted) {
                          return;
                        }
                        final result = ref
                            .read(mysteryProvider.notifier)
                            .submitGuess(
                              picked.id,
                              answerId: answerId,
                              today: today,
                            );
                        final message = switch (result) {
                          GuessResult.won => 'Correct!',
                          GuessResult.lost =>
                            'Game over. You are out of guesses.',
                          GuessResult.wrong =>
                            'Not ${picked.displayName}. A new clue is unlocked.',
                          GuessResult.ignored =>
                            'That guess was already counted.',
                        };
                        showSnack(context, message);
                      }
                    : null,
                icon: const Icon(Icons.search),
                label: const Text('Make a guess'),
              ),
            ],
            const SizedBox(height: Space.lg),
            const SectionLabel('Your record'),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Streak',
                    value: '${streaks.current}',
                  ),
                ),
                Expanded(
                  child: _StatTile(label: 'Best', value: '${streaks.best}'),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Played',
                    value: '${state.history.length}',
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Won',
                    value: state.history.isEmpty
                        ? '–'
                        : '${(state.history.values.where((r) => r.won).length * 100 / state.history.length).round()}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            if (state.history.isNotEmpty)
              MysteryHistory(history: state.history),
          ],
        ),
      ),
    );
  }
}

class _Clues extends StatelessWidget {
  const _Clues({
    required this.detail,
    required this.species,
    required this.revealed,
  });

  final PokemonDetail detail;
  final AsyncValue<PokemonSpecies> species;
  final int revealed;

  String _maskName(String text) {
    var out = text;
    final variants = {
      detail.name,
      detail.name.replaceAll('-', ' '),
      detail.displayName,
    };
    for (final v in variants) {
      if (v.isEmpty) {
        continue;
      }
      out = out.replaceAll(
        RegExp(RegExp.escape(v), caseSensitive: false),
        '▮▮▮▮',
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final gen = generationOf(detail.id);
    final letters = detail.name.replaceAll(RegExp(r'[^a-z]'), '');
    final clues = <String>[
      gen == null
          ? 'Generation unknown.'
          : 'It is from ${generationLabel(gen)}.',
      detail.types.isEmpty
          ? 'PokéAPI lists no types for it.'
          : 'Type: ${detail.types.map(titleCase).join(' / ')}.',
      'Height ${detail.heightM.toStringAsFixed(1)} m, weight ${detail.weightKg.toStringAsFixed(1)} kg, '
          'base stat total ${detail.statTotal}.',
      species.when(
        data: (s) => s.flavorText == null
            ? 'No species description is available.'
            : '“${_maskName(s.flavorText!)}”',
        loading: () => 'Loading species notes…',
        error: (e, _) => 'Species notes are unavailable offline.',
      ),
      letters.isEmpty
          ? 'The name has no plain letters.'
          : 'Its name has ${letters.length} letters and starts with ${letters[0].toUpperCase()}.',
      'Final clue: the picture above is now in color, just slightly blurred.',
    ];

    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Clues'),
        for (var i = 0; i < clues.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Panel(
              color: i < revealed ? null : scheme.surface,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}'.padLeft(2, '0'),
                    style: readoutStyle(context, color: scheme.primary),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: i < revealed
                        ? Text(clues[i])
                        : Text(
                            'Unlocks after $i wrong ${i == 1 ? 'guess' : 'guesses'}.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(label.toUpperCase(), style: readoutStyle(context, size: 10)),
      ],
    );
  }
}
