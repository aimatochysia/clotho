import 'package:clotho/core/git_service.dart';
import 'package:clotho/ui/widgets/commit_graph.dart';
import 'package:flutter_test/flutter_test.dart';

CommitInfo c(String oid, List<String> parents) => CommitInfo(
  oid: oid,
  shortOid: oid,
  summary: oid,
  message: oid,
  authorName: 'a',
  authorEmail: 'a@x',
  time: 0,
  parents: parents,
  refs: const [],
);

void main() {
  test('linear history stays in one lane', () {
    final rows = computeGraph([
      c('3', ['2']),
      c('2', ['1']),
      c('1', []),
    ]);
    expect(rows.map((r) => r.column), [0, 0, 0]);
    expect(rows.every((r) => r.width == 1), isTrue);
    // Tip has no line above; root has no line below.
    expect(rows.first.edges.any((e) => e.$3 == 0), isFalse);
    expect(rows.last.edges.any((e) => e.$3 == 1), isFalse);
  });

  test('merge opens a second lane that rejoins at the fork point', () {
    // M merges F into main; F and B both come from A.
    final rows = computeGraph([
      c('M', ['B', 'F']),
      c('F', ['A']),
      c('B', ['A']),
      c('A', []),
    ]);
    expect(rows[0].column, 0);
    expect(rows[0].edges, contains((0, 1, 1))); // line from M to F's lane
    expect(rows[1].column, 1); // F on its own lane
    expect(rows[2].column, 0); // B back on main lane
    expect(rows[3].column, 0); // A where both lanes converge
    expect(rows[3].edges, contains((1, 0, 0)));
    expect(rows.map((r) => r.width).reduce((x, y) => x > y ? x : y), 2);
  });
}
