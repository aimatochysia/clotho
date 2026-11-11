import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/git_service.dart';

enum PreviewKind { image, aseprite, none }

String _ext(String file) {
  final name = file.split('/').last;
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

/// Formats Flutter can decode itself.
const _imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'wbmp', 'ico'};

PreviewKind previewKindFor(String file) {
  final e = _ext(file);
  if (_imageExts.contains(e)) return PreviewKind.image;
  if (e == 'ase' || e == 'aseprite') return PreviewKind.aseprite;
  return PreviewKind.none;
}

/// A short description for binary files that cannot be previewed.
String describeBinary(String file) {
  final e = _ext(file);
  return switch (e) {
    'pdf' => 'PDF document',
    'psd' => 'Photoshop document',
    'kra' => 'Krita document',
    'xcf' => 'GIMP image',
    'tif' || 'tiff' => 'TIFF image',
    'svgz' => 'Compressed SVG',
    'ttf' || 'otf' || 'woff' || 'woff2' => 'Font',
    'mp3' || 'wav' || 'ogg' || 'flac' || 'm4a' => 'Audio',
    'mp4' || 'mov' || 'webm' || 'mkv' || 'avi' => 'Video',
    'zip' || '7z' || 'rar' || 'gz' || 'tar' || 'xz' => 'Archive',
    'exe' || 'dll' || 'so' || 'dylib' => 'Program file',
    'blend' => 'Blender file',
    'fbx' || 'glb' || 'obj' => '3D model',
    'docx' || 'xlsx' || 'pptx' => 'Office document',
    '' => 'Binary file',
    _ => '.$e file',
  };
}

/// Before/after view of a binary change: images and Aseprite sprites are
/// drawn side by side, anything else is described by type and size.
class BinaryPreview extends StatefulWidget {
  const BinaryPreview({
    super.key,
    required this.file,
    required this.load,
    required this.git,
    this.revision,
  });

  final String file;
  final Future<FileVersions> Function() load;
  final GitService git;

  /// Changes when the file may have changed (a fresh diff). The preview then
  /// reloads quietly and only redraws if the bytes really differ.
  final Object? revision;

  @override
  State<BinaryPreview> createState() => _BinaryPreviewState();
}

bool _sameSide(FileSide a, FileSide b) =>
    a.exists == b.exists &&
    a.size == b.size &&
    (identical(a.data, b.data) || listEquals(a.data, b.data));

class _BinaryPreviewState extends State<BinaryPreview> {
  FileVersions? _data;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BinaryPreview old) {
    super.didUpdateWidget(old);
    if (old.file != widget.file) {
      setState(() {
        _data = null;
        _error = null;
      });
      _load();
    } else if (old.revision != widget.revision) {
      _load();
    }
  }

  Future<void> _load() async {
    final gen = ++_generation;
    try {
      final v = await widget.load();
      if (!mounted || gen != _generation) return;
      final old = _data;
      // Same bytes as on screen: keep the current images, no redraw.
      if (old != null &&
          _sameSide(old.before, v.before) &&
          _sameSide(old.after, v.after)) {
        return;
      }
      setState(() {
        _data = v;
        _error = null;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      // Keep showing the last good preview if a reload fails.
      if (_data == null) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = previewKindFor(widget.file);
    return Builder(
      builder: (context) {
        if (_error != null) {
          return _note(context, Icons.error_outline, '$_error');
        }
        final v = _data;
        if (v == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final sides = [
          if (v.before.exists) ('Before', v.before),
          if (v.after.exists) (v.before.exists ? 'After' : 'Added', v.after),
        ];
        if (!v.after.exists && v.before.exists) {
          sides[0] = ('Deleted', v.before);
        }
        final size = v.before.exists && v.after.exists
            ? '${formatBytes(v.before.size.toInt())} → ${formatBytes(v.after.size.toInt())}'
            : formatBytes((v.after.exists ? v.after : v.before).size.toInt());
        final header = Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(
                kind == PreviewKind.none
                    ? Icons.insert_drive_file_outlined
                    : Icons.image_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${kind == PreviewKind.aseprite ? 'Aseprite sprite (first frame)' : describeBinary(widget.file)} · $size',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
        if (kind == PreviewKind.none) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              _note(
                context,
                Icons.visibility_off_outlined,
                'No preview for this file type.',
              ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, c) {
                  final panes = [
                    for (final (label, side) in sides)
                      _Pane(
                        key: ValueKey(label),
                        label: label,
                        side: side,
                        kind: kind,
                        git: widget.git,
                      ),
                  ];
                  if (c.maxWidth < 520 || panes.length == 1) {
                    return Column(
                      children: [
                        for (final p in panes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: p,
                          ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final p in panes) ...[
                        Expanded(child: p),
                        if (p != panes.last) const SizedBox(width: 12),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

Widget _note(BuildContext context, IconData icon, String text) => Padding(
  padding: const EdgeInsets.all(24),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.outline),
      const SizedBox(width: 8),
      Flexible(child: Text(text)),
    ],
  ),
);

class _Pane extends StatefulWidget {
  const _Pane({
    super.key,
    required this.label,
    required this.side,
    required this.kind,
    required this.git,
  });
  final String label;
  final FileSide side;
  final PreviewKind kind;
  final GitService git;

  @override
  State<_Pane> createState() => _PaneState();
}

class _PaneState extends State<_Pane> {
  late Future<Uint8List?> _bytes = _decode();

  @override
  void didUpdateWidget(_Pane old) {
    super.didUpdateWidget(old);
    if (!_sameSide(old.side, widget.side) || old.kind != widget.kind) {
      _bytes = _decode();
    }
  }

  Future<Uint8List?> _decode() async {
    final data = widget.side.data;
    if (data == null) return null;
    if (widget.kind == PreviewKind.aseprite) {
      return widget.git.renderAseprite(data);
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 280,
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(
              painter: _Checkerboard(
                scheme.surfaceContainerHigh,
                scheme.surfaceContainerLowest,
              ),
              child: FutureBuilder<Uint8List?>(
                future: _bytes,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return _note(
                      context,
                      Icons.broken_image_outlined,
                      'Cannot preview this version.',
                    );
                  }
                  if (snap.connectionState != ConnectionState.done &&
                      !snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final b = snap.data;
                  if (b == null) {
                    return _note(
                      context,
                      Icons.photo_size_select_large,
                      'Too large to preview.',
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.memory(
                      b,
                      // Nearest-neighbour scaling keeps pixel art crisp.
                      filterQuality: FilterQuality.none,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (context, _, _) => _note(
                        context,
                        Icons.broken_image_outlined,
                        'Cannot preview this version.',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Checkerboard extends CustomPainter {
  _Checkerboard(this.a, this.b);
  final Color a;
  final Color b;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 10.0;
    canvas.drawRect(Offset.zero & size, Paint()..color = b);
    final p = Paint()..color = a;
    for (var y = 0.0; y < size.height; y += cell) {
      for (
        var x = ((y / cell).floor().isOdd ? cell : 0.0);
        x < size.width;
        x += cell * 2
      ) {
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), p);
      }
    }
  }

  @override
  bool shouldRepaint(_Checkerboard old) => old.a != a || old.b != b;
}
