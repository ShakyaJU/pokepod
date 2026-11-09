import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/storage/local_store.dart';
import 'onboarding_controller.dart';

/// One screen of the first-run introduction.
///
/// The copy is deliberately short: a sentence of framing plus the handful of
/// things worth knowing, so the flow reads in a minute rather than feeling
/// like a manual.
class OnboardingStep {
  const OnboardingStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.highlights,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String> highlights;
}

/// The introduction, in the order a new trainer meets the app: how to move
/// around, how to look something up, what a dossier holds, what the Lab is
/// for, the daily game, and finally where the settings live.
const List<OnboardingStep> kOnboardingSteps = [
  OnboardingStep(
    icon: Icons.waving_hand_outlined,
    title: 'Welcome to PokéPod',
    body:
        'A pocket companion for every Pokémon you meet — a searchable Pokédex, '
        'real type maths, and a fresh guessing game every day.',
    highlights: [
      'Works offline once the Pokédex has been loaded.',
      'Everything you collect stays on this device.',
      'Nothing is sent anywhere unless you export it yourself.',
    ],
  ),
  OnboardingStep(
    icon: Icons.explore_outlined,
    title: 'Move around in one tap',
    body:
        'Five tabs sit along the bottom of the screen. Tap one, or swipe '
        'sideways — both do exactly the same thing.',
    highlights: [
      'Discover — today\'s specimen, the daily game and recent finds.',
      'Pokédex — the full national list, ready to search.',
      'Lab — Pokémon DNA, Battle Lab and team building.',
      'Collections and Profile — your records, then your settings.',
    ],
  ),
  OnboardingStep(
    icon: Icons.grid_view_rounded,
    title: 'Search the whole Pokédex',
    body:
        'Look up any Pokémon by name or number, then sort and filter until the '
        'list shows exactly what you are researching.',
    highlights: [
      'Search by name, national number, or both at once.',
      'Filter by generation and type; sort by stats, name or number.',
      'Tap any result to open its full dossier.',
    ],
  ),
  OnboardingStep(
    icon: Icons.badge_outlined,
    title: 'Read a Pokémon in full',
    body:
        'Every dossier carries the numbers that matter, plus the matchup maths '
        'and the evolutionary branches behind them.',
    highlights: [
      'Base stats, abilities and a sample of learnable moves.',
      'Defense Profile — what it is weak to, what it resists, what cannot '
          'touch it.',
      'The Evolution Constellation shows every branch at once.',
      'A Research log for your own notes and sightings.',
    ],
  ),
  OnboardingStep(
    icon: Icons.biotech_outlined,
    title: 'Compare, build and collect',
    body:
        'The Lab is where two Pokémon are laid side by side and whole teams '
        'are assembled.',
    highlights: [
      'Pokémon DNA — side-by-side stats, typing and defensive profiles.',
      'Battle Lab — build a team and see what it actually covers.',
      'Collections — organise favourites, teams and sightings.',
    ],
  ),
  OnboardingStep(
    icon: Icons.psychology_alt_outlined,
    title: 'A new Pokémon every day',
    body:
        'Who\'s That Pokémon? gives you six guesses and a stack of clues for '
        'one species that changes at local midnight.',
    highlights: [
      'Make a guess, unlock a clue, keep the streak alive.',
      'The challenge and the streak both reset at local midnight.',
      'Miss a whole day and the streak ends — a reminder is there to help.',
    ],
  ),
  OnboardingStep(
    icon: Icons.person_outline,
    title: 'Make it yours',
    body:
        'Your trainer profile records every streak and achievement, and '
        'Settings controls how PokéPod looks, sounds and notifies you.',
    highlights: [
      'Themes, sound effects and the daily home-screen widget.',
      'Optional streak reminders, three hours before the reset.',
      'Back up and restore everything from Settings.',
    ],
  ),
];

/// Pushes the introduction as a full-screen flow. Completes when the user
/// finishes, skips or backs out — every one of which records it as seen, so
/// the guide can never reappear on its own.
Future<void> showAppOnboarding(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => const OnboardingPage()));

/// The first-run introduction itself.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Records the introduction as seen. Called on Finish, on Skip and on any
  /// back gesture: three routes to the same outcome, so a restart after any of
  /// them starts in the app rather than at step one again.
  Future<void> _recordSeen() =>
      markOnboardingCompleted(ref.read(sharedPreferencesProvider));

  void _go(int index) {
    if (index < 0 || index >= kOnboardingSteps.length) {
      return;
    }
    setState(() => _index = index);
    _pages.animateToPage(index, duration: Motion.medium, curve: Motion.curve);
  }

  Future<void> _close() async {
    await _recordSeen();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = kOnboardingSteps.length;
    final isLast = _index == total - 1;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          unawaited(_recordSeen());
        }
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: Space.md),
                child: Row(
                  children: [
                    Text(
                      'PokéPod',
                      style: readoutStyle(
                        context,
                        size: 12,
                        color: scheme.primary,
                      ),
                    ),
                    const Spacer(),
                    if (!isLast)
                      TextButton(onPressed: _close, child: const Text('Skip')),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  Space.xs,
                  Space.md,
                  Space.sm,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < total; i++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: Motion.medium,
                          curve: Motion.curve,
                          height: 4,
                          margin: EdgeInsets.only(
                            right: i == total - 1 ? 0 : Space.xs,
                          ),
                          decoration: BoxDecoration(
                            color: i <= _index
                                ? scheme.primary
                                : scheme.surface,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    for (final step in kOnboardingSteps) _StepPage(step: step),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Space.md),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: _index == 0 ? null : () => _go(_index - 1),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: isLast ? _close : () => _go(_index + 1),
                        child: Text(isLast ? 'Get started' : 'Next'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Short screens scroll rather than clip: the guide has to stay usable on
    // the smallest phone the app supports, with the keyboard or large text
    // settings in play.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.lg,
          Space.md,
          Space.lg,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(step.icon, size: 36, color: scheme.primary),
              ),
              const SizedBox(height: Space.lg),
              Text(step.title, style: text.headlineSmall),
              const SizedBox(height: Space.sm),
              Text(
                step.body,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: Space.md),
              for (final highlight in step.highlights)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: 10),
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: scheme.primary,
                        ),
                      ),
                      Expanded(child: Text(highlight)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
