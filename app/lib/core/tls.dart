import '../src/rust/api/app.dart' as ra;

/// Lets Git trust the system's certificates (needed on Android). A failure
/// only matters for HTTPS remotes, so it never stops the app from starting.
Future<void> configureTlsSafely(String cacheDir) async {
  try {
    await ra.configureTls(cacheDir: cacheDir);
  } catch (_) {}
}
