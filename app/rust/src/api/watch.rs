use std::collections::HashMap;
use std::path::{Component, Path, PathBuf};
use std::sync::mpsc;
use std::sync::{Mutex, OnceLock};
use std::time::Duration;

use notify::{RecommendedWatcher, RecursiveMode, Watcher};

use crate::error::{CoreError, CoreResult};
use crate::frb_generated::StreamSink;
use crate::util::{self, open_repo};

type Watchers = Mutex<HashMap<PathBuf, RecommendedWatcher>>;

fn watchers() -> &'static Watchers {
    static W: OnceLock<Watchers> = OnceLock::new();
    W.get_or_init(Default::default)
}

/// Quiet period before a burst of file events is reported as one change.
const DEBOUNCE: Duration = Duration::from_millis(400);

/// Starts watching a repository's working tree. The stream emits one event
/// (after a short quiet period) whenever files or refs change, so the UI can
/// refresh status without polling. Changes to Git's object store are ignored.
/// Watching the same repository again replaces the previous watcher.
pub fn watch_repo(path: String, sink: StreamSink<u32>) -> CoreResult<()> {
    let repo = open_repo(&path)?;
    let root = util::workdir(&repo)?.to_path_buf();
    let (tx, rx) = mpsc::channel::<()>();
    let filter_root = root.clone();
    let mut watcher = notify::recommended_watcher(move |res: notify::Result<notify::Event>| {
        if let Ok(event) = res {
            if event.paths.iter().any(|p| is_relevant(&filter_root, p)) {
                let _ = tx.send(());
            }
        }
    })
    .map_err(|e| CoreError::Io {
        message: format!("cannot watch {}: {e}", root.display()),
    })?;
    watcher
        .watch(&root, RecursiveMode::Recursive)
        .map_err(|e| CoreError::Io {
            message: format!("cannot watch {}: {e}", root.display()),
        })?;

    watchers().lock().unwrap().insert(root.clone(), watcher);

    std::thread::spawn(move || {
        let mut seq = 0u32;
        // Ends when the watcher is dropped (sender gone) or Dart closes the stream.
        while rx.recv().is_ok() {
            while rx.recv_timeout(DEBOUNCE).is_ok() {}
            seq = seq.wrapping_add(1);
            if sink.add(seq).is_err() {
                break;
            }
        }
    });
    Ok(())
}

/// Stops watching a repository started with `watch_repo`.
pub fn unwatch_repo(path: String) {
    let key = PathBuf::from(&path);
    let mut map = watchers().lock().unwrap();
    if map.remove(&key).is_none() {
        // The stored key is the workdir; match ignoring a trailing separator.
        let trimmed = util::path_to_string(&key);
        map.retain(|k, _| util::path_to_string(k) != trimmed);
    }
}

fn is_relevant(root: &Path, path: &Path) -> bool {
    let Ok(rel) = path.strip_prefix(root) else {
        return true;
    };
    let mut comps = rel.components();
    match comps.next() {
        Some(Component::Normal(first)) if first == ".git" => {
            // Inside .git only HEAD, the index and refs matter for status.
            match comps.next() {
                Some(Component::Normal(second)) => {
                    let s = second.to_string_lossy();
                    s == "HEAD"
                        || s == "index"
                        || s == "refs"
                        || s == "packed-refs"
                        || s == "MERGE_HEAD"
                }
                _ => false,
            }
        }
        _ => true,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn filters_git_internals() {
        let root = Path::new("/r");
        assert!(is_relevant(root, Path::new("/r/src/main.rs")));
        assert!(is_relevant(root, Path::new("/r/.git/HEAD")));
        assert!(is_relevant(root, Path::new("/r/.git/refs/heads/main")));
        assert!(!is_relevant(root, Path::new("/r/.git/objects/ab/cdef")));
        assert!(!is_relevant(root, Path::new("/r/.git/index.lock")));
    }
}
