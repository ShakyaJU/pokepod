import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/widgets.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import '../../domain/evolution_layout.dart';
import '../shared/navigation.dart';

/// Pannable, zoomable graph of a Pokémon's evolution family, generated from
/// PokéAPI evolution-chain data.
class ConstellationPage extends ConsumerStatefulWidget {
  const ConstellationPage({super.key, required this.pokemonId});

  final int pokemonId;

  @override
  ConsumerState<ConstellationPage> createState() => _ConstellationPageState();
}

class _ConstellationPageState extends ConsumerState<ConstellationPage> {
  final TransformationController _controller = TransformationController();
  bool _fitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fit(Size viewport, Size content) {
    if (_fitted) {
      return;
    }
    _fitted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      var s = viewport.width / content.width;
      final sy = viewport.height / content.height;
      if (sy < s) {
        s = sy;
      }
      if (s > 1) {
        s = 1;
      }
      if (s < 0.3) {
        s = 0.3;
      }
      final tx = (viewport.width - content.width * s) / 2;
      final ty = (viewport.height - content.height * s) / 2;
      _controller.value = Matrix4(
        s,
        0,
        0,
        0,
        0,
        s,
        0,
        0,
        0,
        0,
        1,
        0,
        tx,
        ty,
        0,
        1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chain = ref.watch(evolutionProvider(widget.pokemonId));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Evolution Constellation'),
        actions: [
          IconButton(
            tooltip: 'Reset view',
            icon: const Icon(Icons.center_focus_strong_outlined),
            onPressed: () => setState(() {
              _fitted = false;
              _controller.value = Matrix4.identity();
            }),
          ),
        ],
      ),
      body: chain.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(evolutionProvider(widget.pokemonId)),
        ),
        data: (c) {
          if (c.isSingle) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PokemonArtwork(id: c.root.id, size: 180),
                  const SizedBox(height: Space.md),
                  Text(
                    c.root.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: Space.sm),
                  const Text('This species has no evolutionary relatives.'),
                ],
              ),
            );
          }
          final layout = layoutEvolution(c.root);
          return LayoutBuilder(
            builder: (context, constraints) {
              _fit(
                Size(constraints.maxWidth, constraints.maxHeight),
                layout.size,
              );
              return InteractiveViewer(
                transformationController: _controller,
                constrained: false,
                minScale: 0.3,
                maxScale: 2.5,
                boundaryMargin: const EdgeInsets.all(160),
                child: SizedBox(
                  width: layout.size.width,
                  height: layout.size.height,
                  child: _Graph(layout: layout, selectedId: widget.pokemonId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Graph extends StatelessWidget {
  const _Graph({required this.layout, required this.selectedId});

  final EvolutionLayout layout;
  final int selectedId;

  static const double nodeWidth = 120;
  static const double nodeHeight = 150;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _EdgePainter(edges: layout.edges, color: scheme.primary),
          ),
        ),
        for (final e in layout.edges)
          if (e.label.isNotEmpty)
            Positioned(
              left: e.midpoint.dx - 55,
              top: e.midpoint.dy - 16,
              width: 110,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Text(
                  e.label,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, height: 1.2),
                ),
              ),
            ),
        for (final n in layout.nodes)
          Positioned(
            left: n.center.dx - nodeWidth / 2,
            top: n.center.dy - nodeHeight / 2,
            width: nodeWidth,
            height: nodeHeight,
            child: _NodeCard(
              id: n.node.id,
              name: n.node.displayName,
              selected: n.node.id == selectedId,
            ),
          ),
      ],
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.id,
    required this.name,
    required this.selected,
  });

  final int id;
  final String name;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.12)
          : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selected ? null : () => openDossier(context, id),
        child: Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: Column(
            children: [
              Text(
                selected ? 'SELECTED' : dexNumber(id),
                style: readoutStyle(
                  context,
                  size: 9,
                  color: selected ? scheme.primary : null,
                ),
              ),
              Expanded(child: PokemonArtwork(id: id)),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.edges, required this.color});

  final List<PlacedEdge> edges;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final dot = Paint()..color = color;
    for (final e in edges) {
      final dx = (e.to.dx - e.from.dx) / 2;
      final path = Path()
        ..moveTo(e.from.dx, e.from.dy)
        ..cubicTo(
          e.from.dx + dx,
          e.from.dy,
          e.to.dx - dx,
          e.to.dy,
          e.to.dx,
          e.to.dy,
        );
      canvas.drawPath(path, line);
      canvas.drawCircle(e.from, 3.5, dot);
      canvas.drawCircle(e.to, 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.edges != edges || old.color != color;
}
