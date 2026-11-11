//! Helpers shared by the API modules. Nothing here is exposed to Dart.
use std::path::Path;

use git2::Repository;

use crate::error::{CoreError, CoreResult};

/// Opens the repository at exactly `path`, mapping "not found" to a typed error.
pub(crate) fn open_repo(path: &str) -> CoreResult<Repository> {
    let dir = Path::new(path);
    if !dir.exists() {
        return Err(CoreError::PathNotFound { path: path.into() });
    }
    match Repository::open(dir) {
        Ok(repo) => Ok(repo),
        Err(e) if e.code() == git2::ErrorCode::NotFound => {
            Err(CoreError::NotARepository { path: path.into() })
        }
        Err(e) => Err(e.into()),
    }
}

/// Working directory of a non-bare repo, or an error for bare ones.
pub(crate) fn workdir(repo: &Repository) -> CoreResult<&Path> {
    repo.workdir().ok_or_else(|| CoreError::InvalidInput {
        message: "this action needs a working directory (the repository is bare)".into(),
    })
}

/// Current branch name; errors when HEAD is detached.
pub(crate) fn current_branch(repo: &Repository) -> CoreResult<String> {
    match repo.head() {
        Ok(head) if head.is_branch() => Ok(head.shorthand().unwrap_or_default().to_string()),
        Ok(_) => Err(CoreError::DetachedHead),
        Err(e) if e.code() == git2::ErrorCode::UnbornBranch => repo
            .find_reference("HEAD")
            .ok()
            .and_then(|r| r.symbolic_target().map(str::to_string))
            .map(|t| t.trim_start_matches("refs/heads/").to_string())
            .ok_or(CoreError::DetachedHead),
        Err(e) => Err(e.into()),
    }
}

/// Paths of every conflicted entry in the index.
pub(crate) fn conflicted_paths(repo: &Repository) -> CoreResult<Vec<String>> {
    let index = repo.index()?;
    if !index.has_conflicts() {
        return Ok(vec![]);
    }
    let mut files = vec![];
    for conflict in index.conflicts()? {
        let conflict = conflict?;
        let entry = conflict.our.or(conflict.their).or(conflict.ancestor);
        if let Some(entry) = entry {
            files.push(String::from_utf8_lossy(&entry.path).into_owned());
        }
    }
    files.sort();
    files.dedup();
    Ok(files)
}

pub(crate) fn short_oid(oid: git2::Oid) -> String {
    oid.to_string()[..7].to_string()
}

pub(crate) fn path_to_string(path: &Path) -> String {
    path.to_string_lossy()
        .trim_end_matches(['/', '\\'])
        .to_string()
}

#[cfg(test)]
pub(crate) mod testutil {
    use std::path::Path;

    use git2::{Repository, RepositoryInitOptions, Signature};

    pub struct TestRepo {
        pub dir: tempfile::TempDir,
        pub repo: Repository,
    }

    impl TestRepo {
        pub fn new(branch: &str) -> Self {
            let dir = tempfile::tempdir().unwrap();
            let mut opts = RepositoryInitOptions::new();
            opts.initial_head(branch);
            let repo = Repository::init_opts(dir.path(), &opts).unwrap();
            let mut cfg = repo.config().unwrap();
            cfg.set_str("user.name", "Test User").unwrap();
            cfg.set_str("user.email", "test@example.com").unwrap();
            TestRepo { dir, repo }
        }

        pub fn path(&self) -> String {
            self.dir.path().to_string_lossy().into_owned()
        }

        pub fn write(&self, name: &str, content: &str) {
            let p = self.dir.path().join(name);
            if let Some(parent) = p.parent() {
                std::fs::create_dir_all(parent).unwrap();
            }
            std::fs::write(p, content).unwrap();
        }

        /// Writes `name`, stages it and commits; returns the commit id.
        pub fn commit_file(&self, name: &str, content: &str, msg: &str) -> git2::Oid {
            self.write(name, content);
            let mut index = self.repo.index().unwrap();
            index.add_path(Path::new(name)).unwrap();
            index.write().unwrap();
            let tree = self.repo.find_tree(index.write_tree().unwrap()).unwrap();
            let sig = Signature::now("Test User", "test@example.com").unwrap();
            let parents: Vec<git2::Commit> = match self.repo.head() {
                Ok(h) => vec![h.peel_to_commit().unwrap()],
                Err(_) => vec![],
            };
            let refs: Vec<&git2::Commit> = parents.iter().collect();
            self.repo
                .commit(Some("HEAD"), &sig, &sig, msg, &tree, &refs)
                .unwrap()
        }
    }

    /// A bare "remote" plus a clone of it with one commit pushed, for network tests
    /// that use the local file transport.
    pub struct RemotePair {
        pub remote_dir: tempfile::TempDir,
        pub local: TestRepo,
    }

    impl RemotePair {
        pub fn new() -> Self {
            let remote_dir = tempfile::tempdir().unwrap();
            let mut opts = RepositoryInitOptions::new();
            opts.bare(true).initial_head("main");
            Repository::init_opts(remote_dir.path(), &opts).unwrap();

            let local = TestRepo::new("main");
            local.commit_file("README.md", "hello\n", "initial");
            local
                .repo
                .remote("origin", &remote_url(remote_dir.path()))
                .unwrap();
            {
                let mut remote = local.repo.find_remote("origin").unwrap();
                remote
                    .push(&["refs/heads/main:refs/heads/main"], None)
                    .unwrap();
                // Create the remote-tracking ref so upstream can be set.
                remote.fetch(&[] as &[&str], None, None).unwrap();
                let mut branch = local
                    .repo
                    .find_branch("main", git2::BranchType::Local)
                    .unwrap();
                branch.set_upstream(Some("origin/main")).unwrap();
            }
            RemotePair { remote_dir, local }
        }

        /// A second clone of the remote, used to create commits "someone else" pushed.
        pub fn other_clone(&self) -> TestRepo {
            let dir = tempfile::tempdir().unwrap();
            let repo = Repository::clone(&remote_url(self.remote_dir.path()), dir.path()).unwrap();
            let mut cfg = repo.config().unwrap();
            cfg.set_str("user.name", "Other").unwrap();
            cfg.set_str("user.email", "other@example.com").unwrap();
            TestRepo { dir, repo }
        }
    }

    pub fn remote_url(path: &Path) -> String {
        path.to_string_lossy().into_owned()
    }

    pub fn push_head(repo: &TestRepo) {
        let mut remote = repo.repo.find_remote("origin").unwrap();
        remote
            .push(&["refs/heads/main:refs/heads/main"], None)
            .unwrap();
    }
}
