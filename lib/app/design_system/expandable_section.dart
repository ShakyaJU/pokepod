import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A bordered section whose header toggles its body open and closed.
///
/// Tapping the header always flips the state: a down chevron means "can be
/// expanded", an up chevron (the same icon rotated) means "can be collapsed".
/// The body is not built at all while the section is fully collapsed, so
/// content that loads data is only created once the user opens it.
class ExpandableSection extends StatefulWidget {
  const ExpandableSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget child;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.medium,
    value: widget.initiallyExpanded ? 1 : 0,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Motion.curve,
    reverseCurve: Curves.easeInCubic,
  );
  late bool _expanded = widget.initiallyExpanded;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    setState(() => _expanded = !_expanded);
    if (reduceMotion) {
      _controller.value = _expanded ? 1 : 0;
    } else if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    widget.onExpansionChanged?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A Material (not a decorated Container) so ListTiles and ink splashes inside
    // the body have a Material ancestor to paint on.
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(
          color: _expanded
              ? scheme.primary.withValues(alpha: 0.5)
              : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            label: widget.title,
            hint: _expanded ? 'Double tap to collapse' : 'Double tap to expand',
            excludeSemantics: true,
            onTap: _toggle,
            child: InkWell(
              onTap: _toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.md,
                    vertical: Space.sm,
                  ),
                  child: Row(
                    children: [
                      if (widget.leading != null) ...[
                        IconTheme(
                          data: IconThemeData(color: scheme.primary, size: 22),
                          child: widget.leading!,
                        ),
                        const SizedBox(width: Space.md),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (widget.subtitle != null)
                              Text(
                                widget.subtitle!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      RotationTransition(
                        key: const ValueKey('expandable-chevron'),
                        turns: Tween<double>(
                          begin: 0,
                          end: 0.5,
                        ).animate(_curve),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _curve,
            builder: (context, child) {
              if (_curve.value == 0 && !_expanded) {
                return const SizedBox.shrink();
              }
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _curve.value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                0,
                Space.md,
                Space.md,
              ),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
