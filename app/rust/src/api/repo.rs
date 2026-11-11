use std::path::Path;

use crate::error::CoreError;

/// Basic facts about a repository on disk.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RepoInfo {
    /// Absolute path of the working directory (or the .git folder for a bare repo).
    pub path: String,
    /// Current branch name, or None when HEAD is detached or the repo has no commits.
    pub branch: Option<String>,
    pub is_bare: bool,
    /// True when the repository has no commits yet.
    pub is_empty: bool,
}

/// Opens the repository at exactly `path` (no searching in parent folders) and
/// describes it. Runs on a background thread, so it never blocks the UI.
pub fn inspect_repo(path: String) -> Result<RepoInfo, CoreError> {
    let dir = Path::new(&path);
    if !dir.exists() {
        return Err(CoreError::PathNotFound { path });
    }
    let repo = match git2::Repository::open(dir) {
        Ok(repo) => repo,
        Err(e) if e.code() == git2::ErrorCode::NotFound => {
            return Err(CoreError::NotARepository { path });
        }
        Err(e) => return Err(e.into()),
    };

    let root = repo.workdir().unwrap_or_else(|| repo.path());
    // libgit2's own is_empty() only recognises an unborn `master`, so an unborn
    // HEAD on any branch name is what we treat as "no commits yet".
    let (branch, is_empty) = match repo.head() {
        Ok(head) if head.is_branch() => (head.shorthand().map(str::to_string), false),
        Ok(_) => (None, false),
        // An empty repo has an unborn HEAD; report the branch it will create.
        Err(e) if e.code() == git2::ErrorCode::UnbornBranch => {
            let target = repo
                .find_reference("HEAD")
                .ok()
                .and_then(|r| r.symbolic_target().map(str::to_string))
                .map(|t| t.trim_start_matches("refs/heads/").to_string());
            (target, true)
        }
        Err(e) => return Err(e.into()),
    };

    Ok(RepoInfo {
        path: root
            .to_string_lossy()
            .trim_end_matches(['/', '\\'])
            .to_string(),
        branch,
        is_bare: repo.is_bare(),
        is_empty,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn commit_file(repo: &git2::Repository, name: &str) {
        let workdir = repo.workdir().unwrap();
        std::fs::write(workdir.join(name), "hello").unwrap();
        let mut index = repo.index().unwrap();
        index.add_path(Path::new(name)).unwrap();
        index.write().unwrap();
        let tree = repo.find_tree(index.write_tree().unwrap()).unwrap();
        let sig = git2::Signature::now("Test", "test@example.com").unwrap();
        repo.commit(Some("HEAD"), &sig, &sig, "init", &tree, &[])
            .unwrap();
    }

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
        let dir = tempfile::tempdir().unwrap();
        let mut opts = git2::RepositoryInitOptions::new();
        opts.initial_head("main");
        git2::Repository::init_opts(dir.path(), &opts).unwrap();
        let info = inspect_repo(dir.path().to_string_lossy().into()).unwrap();
        assert!(info.is_empty);
        assert!(!info.is_bare);
        assert_eq!(info.branch.as_deref(), Some("main"));
    }

    #[test]
    fn repo_with_commit_reports_branch() {
        let dir = tempfile::tempdir().unwrap();
        let mut opts = git2::RepositoryInitOptions::new();
        opts.initial_head("dev");
        let repo = git2::Repository::init_opts(dir.path(), &opts).unwrap();
        commit_file(&repo, "a.txt");
        let info = inspect_repo(dir.path().to_string_lossy().into()).unwrap();
        assert!(!info.is_empty);
        assert_eq!(info.branch.as_deref(), Some("dev"));
    }
}
