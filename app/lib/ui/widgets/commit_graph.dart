import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/git_service.dart';

/// One row of the branch graph: where the commit's dot sits and which lines
/// pass through the row.
class GraphRow {
  const GraphRow({
    required this.column,
    required this.edges,
    required this.width,
  });

  /// Lane of this commit's dot.
  final int column;

  /// Line segments as (fromLane, toLane, half): half 0 = top half of the row
  /// (from the row above down to the middle), half 1 = bottom half.
  final List<(int, int, int)> edges;

  /// Number of lanes this row needs.
  final int width;
}

/// Assigns lanes to commits listed newest first (topological order), the way
/// `git log --graph` does, so branches and merges can be drawn.
List<GraphRow> computeGraph(List<CommitInfo> commits) {
  final lanes = <String?>[];
  final rows = <GraphRow>[];

  int allocate(String id, {int? avoid}) {
    for (var i = 0; i < lanes.length; i++) {
      if (lanes[i] == null && i != avoid) {
        lanes[i] = id;
        return i;
      }
    }
    lanes.add(id);
    return lanes.length - 1;
  }

  for (final c in commits) {
    var col = lanes.indexOf(c.oid);
    final hadLane = col != -1;
    if (!hadLane) col = allocate(c.oid);
    final before = List<String?>.of(lanes);
    final edges = <(int, int, int)>[];

    // Top half: live lanes come down; every lane waiting for this commit
    // converges into its dot. A branch tip (no lane above) draws no line.
    for (var j = 0; j < before.length; j++) {
      final id = before[j];
      if (id == null) continue;
      if (id == c.oid) {
        if (j != col || hadLane) edges.add((j, col, 0));
        if (j != col) lanes[j] = null;
      } else {
        edges.add((j, j, 0));
      }
    }

    // Bottom half: first parent continues in this lane, other parents get
    // (or join) their own lane, all other lanes pass straight through.
    lanes[col] = c.parents.isEmpty ? null : c.parents.first;
    final newLanes = <int>{};
    for (final p in c.parents.skip(1)) {
      final existing = lanes.indexOf(p);
      if (existing != -1) {
        edges.add((col, existing, 1));
      } else {
        final k = allocate(p, avoid: col);
        newLanes.add(k);
        edges.add((col, k, 1));
      }
    }
    for (var j = 0; j < lanes.length; j++) {
      if (lanes[j] == null || newLanes.contains(j)) continue;
      edges.add(j == col ? (col, col, 1) : (j, j, 1));
    }

    final width = math.max(math.max(before.length, lanes.length), col + 1);
    while (lanes.isNotEmpty && lanes.last == null) {
      lanes.removeLast();
    }
    rows.add(GraphRow(column: col, edges: edges, width: width));
  }
  return rows;
}

const _laneColors = [
  Color(0xFF0969DA),
  Color(0xFF1A7F37),
  Color(0xFF8250DF),
  Color(0xFFBF3989),
  Color(0xFF9A6700),
  Color(0xFFCF222E),
  Color(0xFF1B7C83),
];

Color laneColor(int lane) => _laneColors[lane % _laneColors.length];

const laneWidth = 16.0;

class GraphCell extends StatelessWidget {
  const GraphCell({
    super.key,
    required this.row,
    required this.maxWidth,
    required this.isHead,
  });
  final GraphRow row;
  final int maxWidth;
  final bool isHead;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(laneWidth * math.min(maxWidth, 8) + 8, double.infinity),
    painter: _GraphPainter(row, isHead, Theme.of(context).colorScheme.surface),
  );
}

class _GraphPainter extends CustomPainter {
  _GraphPainter(this.row, this.isHead, this.background);
  final GraphRow row;
  final bool isHead;
  final Color background;

  double _x(int lane) => 4 + laneWidth * math.min(lane, 7) + laneWidth / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    for (final (from, to, half) in row.edges) {
      final paint = Paint()
        ..color = laneColor(half == 0 ? from : to)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final y0 = half == 0 ? 0.0 : mid;
      final y1 = half == 0 ? mid : size.height;
      final path = Path()..moveTo(_x(from), y0);
      if (from == to) {
        path.lineTo(_x(to), y1);
      } else {
        path.cubicTo(
          _x(from),
          (y0 + y1) / 2,
          _x(to),
          (y0 + y1) / 2,
          _x(to),
          y1,
        );
      }
      canvas.drawPath(path, paint);
    }
    final c = Offset(_x(row.column), mid);
    final color = laneColor(row.column);
    canvas.drawCircle(c, 5.5, Paint()..color = color);
    if (isHead) {
      canvas.drawCircle(c, 3, Paint()..color = background);
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.row != row || old.isHead != isHead;
}
