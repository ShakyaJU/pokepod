import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/widgets.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../domain/mystery_logic.dart';

/// How the hidden Pokémon is drawn at one point in the game.
class RevealStage {
  const RevealStage({
    required this.index,
    required this.showImage,
    required this.blurSigma,
    required this.colour,
    required this.saturation,
  });

  /// 0 (fully hidden) to 5 (clearest, last attempt).
  final int index;
  final bool showImage;
  final double blurSigma;

  /// False: a flat silhouette. True: the real colours, partly desaturated.
  final bool colour;
  final double saturation;
}

/// Stage for the number of guesses already made. Driven only by the persisted
/// guess list, so reopening the screen or rebuilding can never advance it.
///
/// 0 guesses: just the "?"; then a heavily blurred silhouette that sharpens
/// with every wrong guess; and on the last attempt the artwork in (muted) colour.
RevealStage revealStageFor(int guessesMade) {
  final n = math.min(math.max(guessesMade, 0), kMysteryMaxGuesses - 1);
  switch (n) {
    case 0:
      return const RevealStage(
        index: 0,
        showImage: false,
        blurSigma: 0,
        colour: false,
        saturation: 0,
      );
    case 1:
      return const RevealStage(
        index: 1,
        showImage: true,
        blurSigma: 22,
        colour: false,
        saturation: 0,
      );
    case 2:
      return const RevealStage(
        index: 2,
        showImage: true,
        blurSigma: 13,
        colour: false,
        saturation: 0,
      );
    case 3:
      return const RevealStage(
        index: 3,
        showImage: true,
        blurSigma: 6,
        colour: false,
        saturation: 0,
      );
    case 4:
      return const RevealStage(
        index: 4,
        showImage: true,
        blurSigma: 0,
        colour: false,
        saturation: 0,
      );
    default:
      return const RevealStage(
        index: 5,
        showImage: true,
        blurSigma: 2.5,
        colour: true,
        saturation: 0.55,
      );
  }
}

/// Colour matrix that scales saturation (1 = unchanged, 0 = greyscale).
List<double> saturationMatrix(double s) {
  const lr = 0.2126;
  const lg = 0.7152;
  const lb = 0.0722;
  final inv = 1 - s;
  return [
    lr * inv + s,
    lg * inv,
    lb * inv,
    0,
    0,
    lr * inv,
    lg * inv + s,
    lb * inv,
    0,
    0,
    lr * inv,
    lg * inv,
    lb * inv + s,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

/// The picture area of "Who's That Pokémon?": a "?" until the first wrong
/// guess, then the real artwork made clearer stage by stage, and finally the
/// full artwork once the day is completed.
class MysteryReveal extends ConsumerWidget {
  const MysteryReveal({
    super.key,
    required this.answerId,
    required this.guessesMade,
    required this.completed,
  });

  final int answerId;
  final int guessesMade;
  final bool completed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final stage = revealStageFor(guessesMade);

    final Widget content;
    final String semantics;
    if (completed) {
      semantics = 'The mystery Pokémon, revealed.';
      content = TweenAnimationBuilder<double>(
        key: const ValueKey('mystery-final'),
        tween: Tween(begin: 0.6, end: 1),
        duration: Motion.slow,
        curve: Curves.easeOutBack,
        builder: (context, scale, child) => Opacity(
          opacity: ((scale - 0.6) / 0.4).clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        ),
        child: PokemonArtwork(id: answerId, size: 200),
      );
    } else if (!stage.showImage) {
      semantics = 'Mystery Pokémon, hidden. Make a guess to reveal more.';
      content = const _QuestionMark(key: ValueKey('mystery-question'));
    } else {
      semantics =
          'Mystery Pokémon, stage ${stage.index} of 5, '
          '${stage.colour ? 'shown in muted color' : 'shown as a silhouette'}.';
      content = _StagedPicture(
        key: ValueKey(
          'mystery-picture-${stage.colour ? 'colour' : 'silhouette'}',
        ),
        answerId: answerId,
        stage: stage,
      );
    }

    return Semantics(
      label: semantics,
      image: true,
      excludeSemantics: true,
      child: Container(
        height: 240,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: scheme.outlineVariant),
          gradient: RadialGradient(
            colors: [
              scheme.primary.withValues(alpha: completed ? 0.28 : 0.16),
              scheme.surfaceContainerLow,
            ],
            radius: 0.8,
          ),
        ),
        child: AnimatedSwitcher(duration: Motion.medium, child: content),
      ),
    );
  }
}

class _QuestionMark extends StatelessWidget {
  const _QuestionMark({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [scheme.primary, scheme.secondary],
      ).createShader(rect),
      child: const Text(
        '?',
        style: TextStyle(
          fontSize: 130,
          fontWeight: FontWeight.w800,
          height: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _StagedPicture extends ConsumerWidget {
  const _StagedPicture({
    super.key,
    required this.answerId,
    required this.stage,
  });

  final int answerId;
  final RevealStage stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factory = ref.watch(imageProviderFactoryProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final silhouette = dark ? const Color(0xFFE6EEF5) : const Color(0xFF0E1A21);

    final image = Image(
      image: factory(artworkUrl(answerId)),
      width: 200,
      height: 200,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => const _QuestionMark(),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(end: stage.blurSigma),
      duration: Motion.slow,
      curve: Curves.easeOutCubic,
      builder: (context, sigma, _) {
        Widget picture = stage.colour
            ? ColorFiltered(
                colorFilter: ColorFilter.matrix(
                  saturationMatrix(stage.saturation),
                ),
                child: image,
              )
            : ColorFiltered(
                colorFilter: ColorFilter.mode(silhouette, BlendMode.srcIn),
                child: image,
              );
        if (sigma > 0.05) {
          picture = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma,
              tileMode: TileMode.decal,
            ),
            child: picture,
          );
        }
        return SizedBox(width: 200, height: 200, child: Center(child: picture));
      },
    );
  }
}
