import 'dart:ui';

import '../data/models/pokemon.dart';

class PlacedNode {
  const PlacedNode({
    required this.node,
    required this.center,
    required this.depth,
  });

  final EvoNode node;
  final Offset center;
  final int depth;
}

class PlacedEdge {
  const PlacedEdge({
    required this.fromId,
    required this.toId,
    required this.from,
    required this.to,
    required this.label,
  });

  final int fromId;
  final int toId;
  final Offset from;
  final Offset to;
  final String label;

  Offset get midpoint => Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
}

class EvolutionLayout {
  const EvolutionLayout({
    required this.nodes,
    required this.edges,
    required this.size,
  });

  final List<PlacedNode> nodes;
  final List<PlacedEdge> edges;
  final Size size;
}

/// Lays a (tree-shaped) evolution family out left-to-right.
///
/// Every leaf gets its own row, so nodes can never overlap no matter how
/// many branches a family has; parents are centred over their children and
/// the total size is bounded by `leaves * rowHeight` by `depth * columnWidth`.
EvolutionLayout layoutEvolution(
  EvoNode root, {
  double nodeWidth = 120,
  double nodeHeight = 150,
  double columnGap = 120,
  double rowGap = 24,
  double padding = 32,
}) {
  final nodes = <PlacedNode>[];
  final edges = <PlacedEdge>[];
  var nextRow = 0;
  var maxDepth = 0;
  final rowHeight = nodeHeight + rowGap;
  final columnWidth = nodeWidth + columnGap;

  // Returns the vertical centre of the placed node.
  double place(EvoNode node, int depth) {
    if (depth > maxDepth) {
      maxDepth = depth;
    }
    final x = padding + depth * columnWidth + nodeWidth / 2;
    double y;
    final childCentres = <double>[];
    final childNodes = <EvoNode>[];
    final childLabels = <String>[];
    for (final link in node.links) {
      childCentres.add(place(link.node, depth + 1));
      childNodes.add(link.node);
      childLabels.add(link.condition);
    }
    if (childCentres.isEmpty) {
      y = padding + nextRow * rowHeight + nodeHeight / 2;
      nextRow++;
    } else {
      y = (childCentres.first + childCentres.last) / 2;
    }
    final here = Offset(x, y);
    nodes.add(PlacedNode(node: node, center: here, depth: depth));
    for (var i = 0; i < childNodes.length; i++) {
      final childX = padding + (depth + 1) * columnWidth + nodeWidth / 2;
      edges.add(
        PlacedEdge(
          fromId: node.id,
          toId: childNodes[i].id,
          from: Offset(x + nodeWidth / 2, y),
          to: Offset(childX - nodeWidth / 2, childCentres[i]),
          label: childLabels[i],
        ),
      );
    }
    return y;
  }

  place(root, 0);
  final width = padding * 2 + (maxDepth + 1) * nodeWidth + maxDepth * columnGap;
  final height = padding * 2 + nextRow * nodeHeight + (nextRow - 1) * rowGap;
  nodes.sort((a, b) {
    final d = a.depth.compareTo(b.depth);
    return d != 0 ? d : a.center.dy.compareTo(b.center.dy);
  });
  return EvolutionLayout(nodes: nodes, edges: edges, size: Size(width, height));
}
