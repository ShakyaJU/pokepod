import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import '../../domain/research_rules.dart';
import '../theme/app_theme.dart';
import 'meta_badge.dart';
import '../theme/tokens.dart';

/// Factory for network images. Production uses the disk-caching provider;
/// tests override it with an in-memory image.
final imageProviderFactoryProvider =
    Provider<ImageProvider Function(String url)>(
      (ref) =>
          (url) => CachedNetworkImageProvider(url),
    );

/// Official artwork with a sprite fallback and then an icon fallback.
class PokemonArtwork extends ConsumerWidget {
  const PokemonArtwork({
    super.key,
    required this.id,
    this.size,
    this.shiny = false,
    this.silhouette = false,
    this.fit = BoxFit.contain,
  });

  final int id;
  final double? size;
  final bool shiny;

  /// Renders only the outline, for undiscovered entries and the Mystery game.
  final bool silhouette;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factory = ref.watch(imageProviderFactoryProvider);
    final scheme = Theme.of(context).colorScheme;

    Widget fallback() => Center(
      child: Icon(
        Icons.catching_pokemon,
        size: (size ?? 64) * 0.4,
        color: scheme.outline,
      ),
    );

    Widget image = Image(
      image: factory(shiny ? shinyArtworkUrl(id) : artworkUrl(id)),
      width: size,
      height: size,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) {
        if (sync) {
          return child;
        }
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: Motion.medium,
          child: child,
        );
      },
      errorBuilder: (context, error, stack) => Image(
        image: factory(spriteUrl(id)),
        width: size,
        height: size,
        fit: fit,
        filterQuality: FilterQuality.none,
        errorBuilder: (context, error, stack) => fallback(),
      ),
    );

    if (silhouette) {
      image = ColorFiltered(
        colorFilter: ColorFilter.mode(
          scheme.surfaceContainerHighest,
          BlendMode.srcIn,
        ),
        child: image,
      );
    }
    return SizedBox(width: size, height: size, child: image);
  }
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.md),
    this.onTap,
    this.borderColor,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(Radii.md);
    return Material(
      color: color ?? scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor ?? scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(text.toUpperCase(), style: readoutStyle(context)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class TypeChip extends StatelessWidget {
  const TypeChip(this.type, {super.key, this.dense = false});

  final String type;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return MetaBadge(
      label: titleCase(type),
      color: typeColor(type),
      dot: true,
      dense: dense,
    );
  }
}

class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.label,
    required this.value,
    this.max = 255,
    this.color,
  });

  final String label;
  final int value;
  final int max;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = color ?? scheme.primary;
    final fraction = (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label.toUpperCase(),
              style: readoutStyle(context, size: 10),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: scheme.surfaceContainerHigh),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fraction),
                      duration: Motion.slow,
                      curve: Motion.curve,
                      builder: (context, v, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: v,
                        child: ColoredBox(color: fill),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing placeholder used while data loads.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = Radii.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.45 + 0.4 * _controller.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: Space.md),
            Text(describeError(error), textAlign: TextAlign.center),
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: scheme.primary.withValues(alpha: 0.8)),
            const SizedBox(height: Space.md),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: Space.md), action!],
          ],
        ),
      ),
    );
  }
}

/// Honest connectivity indicator: only shown after a request actually failed.
class LiveStatusBanner extends ConsumerWidget {
  const LiveStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveStatusProvider);
    if (state != LiveState.offline) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      color: scheme.tertiary.withValues(alpha: 0.16),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 16, color: scheme.tertiary),
          const SizedBox(width: Space.sm),
          const Expanded(
            child: Text(
              'Offline: showing only data already saved on this device.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class ResearchBadge extends StatelessWidget {
  const ResearchBadge(this.state, {super.key, this.size = 16});

  final ResearchState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (state) {
      ResearchState.unseen => (Icons.radio_button_unchecked, scheme.outline),
      ResearchState.discovered => (Icons.visibility_outlined, scheme.secondary),
      ResearchState.studied => (Icons.menu_book_outlined, scheme.primary),
      ResearchState.mastered => (Icons.workspace_premium, scheme.tertiary),
    };
    return Tooltip(
      message: state.label,
      child: Icon(icon, size: size, color: color),
    );
  }
}

/// Page header for the five main tabs.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.md,
        Space.md,
        Space.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(subtitle!.toUpperCase(), style: readoutStyle(context)),
                Text(title, style: theme.textTheme.headlineMedium),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}
