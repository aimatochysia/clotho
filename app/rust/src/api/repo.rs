use std::path::Path;

use git2::{Repository, StatusOptions};

use crate::error::{CoreError, CoreResult};
use crate::util::{self, open_repo};

/// Basic facts about a repository on disk.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RepoInfo {
    /// Absolute path of the working directory (or the .git folder for a bare repo).
    pub path: String,
    /// Current branch name, or None when HEAD is detached.
    pub branch: Option<String>,
    pub is_bare: bool,
    /// True when the repository has no commits yet.
    pub is_empty: bool,
}

/// Opens the repository at exactly `path` (no searching in parent folders).
pub fn inspect_repo(path: String) -> CoreResult<RepoInfo> {
    let repo = open_repo(&path)?;
    let root = repo.workdir().unwrap_or_else(|| repo.path());
    // libgit2's own is_empty() only recognises an unborn `master`, so an unborn
    // HEAD on any branch name is what we treat as "no commits yet".
    let is_empty = matches!(repo.head(), Err(e) if e.code() == git2::ErrorCode::UnbornBranch);
    Ok(RepoInfo {
        path: util::path_to_string(root),
        branch: util::current_branch(&repo).ok(),
        is_bare: repo.is_bare(),
        is_empty,
    })
}

/// Folder names never descended into while scanning; they are huge and never
/// hold repositories a person wants to manage.
const SKIP_DIRS: &[&str] = &[
    "node_modules",
    "target",
    "build",
    "dist",
    "vendor",
    "Pods",
    "DerivedData",
    "__pycache__",
    "$RECYCLE.BIN",
    "System Volume Information",
];

/// Finds every Git repository under `root`, up to `max_depth` folders deep.
/// A found repository is not searched further (its submodules are skipped).
/// Symlinks and hidden folders are not followed.
pub fn scan_for_repos(root: String, max_depth: u32) -> CoreResult<Vec<String>> {
    let root_path = Path::new(&root);
    if !root_path.is_dir() {
        return Err(CoreError::PathNotFound { path: root });
    }
    let mut found = vec![];
    scan_dir(root_path, 0, max_depth.min(8), &mut found);
    found.sort();
    Ok(found)
}

fn scan_dir(dir: &Path, depth: u32, max_depth: u32, found: &mut Vec<String>) {
    if dir.join(".git").exists() {
        found.push(util::path_to_string(dir));
        return;
    }
    if depth >= max_depth || found.len() >= 5000 {
        return;
    }
    let Ok(entries) = std::fs::read_dir(dir) else {
        return; // unreadable folders (permissions) are skipped silently
    };
    for entry in entries.flatten() {
        let Ok(kind) = entry.file_type() else {
            continue;
        };
        if !kind.is_dir() || kind.is_symlink() {
            continue;
        }
        let name = entry.file_name();
        let name = name.to_string_lossy();
        if name.starts_with('.') || SKIP_DIRS.contains(&name.as_ref()) {
            continue;
        }
        scan_dir(&entry.path(), depth + 1, max_depth, found);
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ChangeKind {
    Added,
    Modified,
    Deleted,
    Renamed,
    TypeChanged,
    Untracked,
}

/// One changed file. A file can have both staged and unstaged changes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FileChange {
    pub path: String,
    /// Previous path when the file was renamed.
    pub old_path: Option<String>,
    pub staged: Option<ChangeKind>,
    pub unstaged: Option<ChangeKind>,
    pub conflicted: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RepoState {
    Clean,
    Merging,
    Rebasing,
    CherryPicking,
    Reverting,
    Bisecting,
    Other,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RepoStatus {
    pub path: String,
    /// None when HEAD is detached.
    pub branch: Option<String>,
    pub head_short_oid: Option<String>,
    /// For example `origin/main`.
    pub upstream: Option<String>,
    /// Commits on the local branch that the upstream does not have.
    pub ahead: u32,
    /// Commits on the upstream that the local branch does not have.
    pub behind: u32,
    pub state: RepoState,
    pub files: Vec<FileChange>,
    pub staged_count: u32,
    pub unstaged_count: u32,
    pub conflicted_count: u32,
}

/// Full working-tree status, including ahead/behind against the upstream.
pub fn repo_status(path: String) -> CoreResult<RepoStatus> {
    let repo = open_repo(&path)?;
    util::workdir(&repo)?;
    status_of(&repo, &path)
}

pub(crate) fn status_of(repo: &Repository, path: &str) -> CoreResult<RepoStatus> {
    let branch = util::current_branch(repo).ok();
    let head_oid = repo.head().ok().and_then(|h| h.target());

    let (upstream, ahead, behind) = match &branch {
        Some(name) => upstream_counts(repo, name),
        None => (None, 0, 0),
    };

    let mut opts = StatusOptions::new();
    opts.include_untracked(true)
        .recurse_untracked_dirs(true)
        .renames_head_to_index(true)
        .exclude_submodules(true)
        // Write refreshed file stat info back to the index when possible.
        // Without it libgit2 re-hashes unchanged files on every call, which
        // made status take over a second on large repositories.
        .update_index(true);
    let statuses = repo.statuses(Some(&mut opts))?;

    let mut files = vec![];
    for entry in statuses.iter() {
        let s = entry.status();
        if s.is_ignored() {
            continue;
        }
        let conflicted = s.is_conflicted();
        let staged = if s.is_index_new() {
            Some(ChangeKind::Added)
        } else if s.is_index_modified() {
            Some(ChangeKind::Modified)
        } else if s.is_index_deleted() {
            Some(ChangeKind::Deleted)
        } else if s.is_index_renamed() {
            Some(ChangeKind::Renamed)
        } else if s.is_index_typechange() {
            Some(ChangeKind::TypeChanged)
        } else {
            None
        };
        let unstaged = if s.is_wt_new() {
            Some(ChangeKind::Untracked)
        } else if s.is_wt_modified() {
            Some(ChangeKind::Modified)
        } else if s.is_wt_deleted() {
            Some(ChangeKind::Deleted)
        } else if s.is_wt_renamed() {
            Some(ChangeKind::Renamed)
        } else if s.is_wt_typechange() {
            Some(ChangeKind::TypeChanged)
        } else {
            None
        };
        if staged.is_none() && unstaged.is_none() && !conflicted {
            continue;
        }
        let delta = entry.head_to_index().or_else(|| entry.index_to_workdir());
        let new_path = delta
            .as_ref()
            .and_then(|d| d.new_file().path())
            .map(|p| p.to_string_lossy().into_owned())
            .or_else(|| entry.path().map(str::to_string))
            .unwrap_or_default();
        let old_path = delta
            .as_ref()
            .and_then(|d| d.old_file().path())
            .map(|p| p.to_string_lossy().into_owned())
            .filter(|old| *old != new_path);
        files.push(FileChange {
            path: new_path,
            old_path,
            staged,
            unstaged,
            conflicted,
        });
    }
    files.sort_by(|a, b| a.path.cmp(&b.path));

    let state = match repo.state() {
        git2::RepositoryState::Clean => RepoState::Clean,
        git2::RepositoryState::Merge => RepoState::Merging,
        git2::RepositoryState::Rebase
        | git2::RepositoryState::RebaseInteractive
        | git2::RepositoryState::RebaseMerge
        | git2::RepositoryState::ApplyMailbox
        | git2::RepositoryState::ApplyMailboxOrRebase => RepoState::Rebasing,
        git2::RepositoryState::CherryPick | git2::RepositoryState::CherryPickSequence => {
            RepoState::CherryPicking
        }
        git2::RepositoryState::Revert | git2::RepositoryState::RevertSequence => {
            RepoState::Reverting
        }
        git2::RepositoryState::Bisect => RepoState::Bisecting,
    };

    Ok(RepoStatus {
        path: path.to_string(),
        branch,
        head_short_oid: head_oid.map(util::short_oid),
        upstream,
        ahead,
        behind,
        state,
        staged_count: files.iter().filter(|f| f.staged.is_some()).count() as u32,
        unstaged_count: files.iter().filter(|f| f.unstaged.is_some()).count() as u32,
        conflicted_count: files.iter().filter(|f| f.conflicted).count() as u32,
        files,
    })
}

/// Upstream name and ahead/behind counts for a local branch.
pub(crate) fn upstream_counts(repo: &Repository, branch: &str) -> (Option<String>, u32, u32) {
    let Ok(local) = repo.find_branch(branch, git2::BranchType::Local) else {
        return (None, 0, 0);
    };
    let Ok(up) = local.upstream() else {
        return (None, 0, 0);
    };
    let name = up.name().ok().flatten().map(str::to_string);
    let (Some(l), Some(u)) = (local.get().target(), up.get().target()) else {
        return (name, 0, 0);
    };
    let (ahead, behind) = repo.graph_ahead_behind(l, u).unwrap_or((0, 0));
    (name, ahead as u32, behind as u32)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::util::testutil::*;

    #[test]
    fn missing_path_is_reported() {
        let err = inspect_repo("/definitely/not/here".into()).unwrap_err();
        assert!(matches!(err, CoreError::PathNotFound { .. }));
    }

    #[test]
    fn plain_folder_is_not_a_repo() {
        let dir = tempfile::tempdir().unwrap();
        let err = inspect_repo(dir.path().to_string_lossy().into()).unwrap_err();
        assert!(matches!(err, CoreError::NotARepository { .. }));
    }

    #[test]
    fn empty_repo_reports_unborn_branch() {
        let t = TestRepo::new("main");
        let info = inspect_repo(t.path()).unwrap();
        assert!(info.is_empty);
        assert!(!info.is_bare);
        assert_eq!(info.branch.as_deref(), Some("main"));
    }

    #[test]
    fn repo_with_commit_reports_branch() {
        let t = TestRepo::new("dev");
        t.commit_file("a.txt", "a", "init");
        let info = inspect_repo(t.path()).unwrap();
        assert!(!info.is_empty);
        assert_eq!(info.branch.as_deref(), Some("dev"));
    }

    #[test]
    fn scan_finds_nested_repos_and_skips_junk() {
        let root = tempfile::tempdir().unwrap();
        for p in ["a", "group/b", "node_modules/c", ".hidden/d", "a/inner"] {
            let dir = root.path().join(p);
            std::fs::create_dir_all(&dir).unwrap();
            Repository::init(&dir).unwrap();
        }
        let found = scan_for_repos(root.path().to_string_lossy().into(), 3).unwrap();
        let names: Vec<String> = found
            .iter()
            .map(|f| {
                Path::new(f)
                    .strip_prefix(root.path())
                    .unwrap()
                    .to_string_lossy()
                    .replace('\\', "/")
            })
            .collect();
        assert_eq!(names, vec!["a", "group/b"]);
    }

    #[test]
    fn scan_respects_depth() {
        let root = tempfile::tempdir().unwrap();
        let deep = root.path().join("x/y/z");
        std::fs::create_dir_all(&deep).unwrap();
        Repository::init(&deep).unwrap();
        let shallow = scan_for_repos(root.path().to_string_lossy().into(), 2).unwrap();
        assert!(shallow.is_empty());
        let deeper = scan_for_repos(root.path().to_string_lossy().into(), 3).unwrap();
        assert_eq!(deeper.len(), 1);
    }

    #[test]
    fn status_lists_staged_unstaged_and_untracked() {
        let t = TestRepo::new("main");
        t.commit_file("tracked.txt", "one\n", "init");
        t.write("tracked.txt", "two\n");
        t.write("new.txt", "new\n");
        t.write("staged.txt", "s\n");
        let mut index = t.repo.index().unwrap();
        index.add_path(Path::new("staged.txt")).unwrap();
        index.write().unwrap();

        let st = repo_status(t.path()).unwrap();
        assert_eq!(st.branch.as_deref(), Some("main"));
        assert_eq!(st.state, RepoState::Clean);
        let find = |p: &str| st.files.iter().find(|f| f.path == p).unwrap().clone();
        assert_eq!(find("tracked.txt").unstaged, Some(ChangeKind::Modified));
        assert_eq!(find("new.txt").unstaged, Some(ChangeKind::Untracked));
        assert_eq!(find("staged.txt").staged, Some(ChangeKind::Added));
        assert_eq!(st.staged_count, 1);
        assert_eq!(st.unstaged_count, 2);
    }

    #[test]
    fn status_counts_ahead_and_behind() {
        let pair = RemotePair::new();
        let other = pair.other_clone();
        other.commit_file("theirs.txt", "x", "theirs");
        push_head(&other);
        pair.local.commit_file("mine.txt", "y", "mine");
        let mut remote = pair.local.repo.find_remote("origin").unwrap();
        remote.fetch(&[] as &[&str], None, None).unwrap();

        let st = repo_status(pair.local.path()).unwrap();
        assert_eq!(st.upstream.as_deref(), Some("origin/main"));
        assert_eq!((st.ahead, st.behind), (1, 1));
    }
}
