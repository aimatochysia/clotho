import 'package:clotho/core/format.dart';
import 'package:clotho/ui/github/clone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('folder name from clone URL', () {
    expect(repoNameFromUrl('https://github.com/octo/hello.git'), 'hello');
    expect(repoNameFromUrl('git@github.com:octo/hello.git'), 'hello');
    expect(repoNameFromUrl('https://example.com/a/b/'), 'b');
    expect(repoNameFromUrl(''), '');
  });

  test('relative ISO times', () {
    final now = DateTime.utc(2026, 11, 11, 12);
    expect(relativeIso('2026-11-11T11:00:00Z', now: now), '1 h ago');
    expect(relativeIso(null, now: now), '');
    expect(relativeIso('garbage', now: now), '');
  });

  test('byte sizes', () {
    expect(formatBytes(500), '500 B');
    expect(formatBytes(2048), '2.0 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
  });
}
