import '../src/rust/api/repo.dart';
import '../src/rust/error.dart';

/// Result of looking at a folder, already turned into text the UI can show.
sealed class InspectResult {
  const InspectResult();
}

class InspectFound extends InspectResult {
  const InspectFound(this.info);
  final RepoInfo info;
}

class InspectFailed extends InspectResult {
  const InspectFailed(this.message);
  final String message;
}

/// Seam between the UI and the Rust core, so widgets can be tested without
/// loading the native library.
abstract interface class RepoInspector {
  Future<InspectResult> inspect(String path);
}

class RustRepoInspector implements RepoInspector {
  const RustRepoInspector();

  @override
  Future<InspectResult> inspect(String path) async {
    try {
      return InspectFound(await inspectRepo(path: path));
    } on CoreError catch (e) {
      return InspectFailed(describeCoreError(e));
    }
  }
}

String describeCoreError(CoreError error) => switch (error) {
  CoreError_NotARepository(:final path) => 'Not a Git repository: $path',
  CoreError_PathNotFound(:final path) => 'Folder not found: $path',
  CoreError_Git(:final message) => 'Git error: $message',
};
