use std::cell::Cell;
use std::path::PathBuf;

use git2::{
    AnnotatedCommit, BranchType, Cred, CredentialType, FetchOptions, PushOptions, RemoteCallbacks,
    Repository,
};
use serde::{Deserialize, Serialize};

use crate::api::branches::switch_to;
use crate::error::{CoreError, CoreResult};
use crate::util::{self, open_repo};

/// Credentials offered to remotes. With no token, Clotho falls back to the
/// system Git credential helper (for example Git Credential Manager) for
/// HTTPS, and to the SSH agent or `~/.ssh` keys for SSH.
#[derive(Debug, Clone, Default)]
pub struct AuthOptions {
    /// A GitHub OAuth or personal access token, used for HTTPS remotes.
    pub token: Option<String>,
    /// Username sent with the token. Defaults to `x-access-token`.
    pub username: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum PullStrategy {
    /// Only move the branch forward; refuse when histories have diverged.
    FastForwardOnly,
    /// Create a merge commit when histories have diverged.
    Merge,
    /// Replay local commits on top of the upstream.
    Rebase,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PullOutcome {
    UpToDate,
    FastForwarded,
    Merged,
    Rebased,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PullResult {
    pub outcome: PullOutcome,
    /// Commits brought in from the upstream.
    pub new_commits: u32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FetchResult {
    pub remotes: Vec<String>,
    pub received_objects: u32,
}

pub(crate) fn callbacks<'a>(auth: &'a AuthOptions, config: git2::Config) -> RemoteCallbacks<'a> {
    let mut cb = RemoteCallbacks::new();
    let attempts = Cell::new(0u32);
    let ssh_keys: Vec<PathBuf> = dirs::home_dir()
        .map(|h| {
            ["id_ed25519", "id_ecdsa", "id_rsa"]
                .iter()
                .map(|k| h.join(".ssh").join(k))
                .filter(|p| p.exists())
                .collect()
        })
        .unwrap_or_default();
    cb.credentials(move |url, username_from_url, allowed| {
        // libgit2 calls this again after each rejected credential; stop after a
        // few tries so a wrong token gives an auth error instead of a loop.
        let n = attempts.get();
        attempts.set(n + 1);
        if n > 6 {
            return Err(git2::Error::new(
                git2::ErrorCode::Auth,
                git2::ErrorClass::Http,
                "credentials were rejected",
            ));
        }
        if allowed.contains(CredentialType::USERNAME) {
            return Cred::username(username_from_url.unwrap_or("git"));
        }
        if allowed.contains(CredentialType::SSH_KEY) {
            let user = username_from_url.unwrap_or("git");
            if n == 0 {
                if let Ok(c) = Cred::ssh_key_from_agent(user) {
                    return Ok(c);
                }
            }
            let idx = n.saturating_sub(1) as usize;
            if let Some(key) = ssh_keys.get(idx).or(ssh_keys.first()) {
                return Cred::ssh_key(user, None, key, None);
            }
        }
        if allowed.contains(CredentialType::USER_PASS_PLAINTEXT) {
            // Only hand the GitHub token to GitHub, never to other hosts.
            if let (Some(token), 0..=1, true) = (&auth.token, n, is_github_url(url)) {
                let user = auth.username.as_deref().unwrap_or("x-access-token");
                return Cred::userpass_plaintext(user, token);
            }
            return Cred::credential_helper(&config, url, username_from_url);
        }
        if allowed.contains(CredentialType::DEFAULT) {
            return Cred::default();
        }
        Err(git2::Error::new(
            git2::ErrorCode::Auth,
            git2::ErrorClass::Net,
            "no usable credentials for this remote",
        ))
    });
    cb
}

/// True when `url` points at github.com over HTTPS.
pub(crate) fn is_github_url(url: &str) -> bool {
    match url::Url::parse(url) {
        Ok(u) => {
            u.scheme() == "https"
                && matches!(u.host_str(), Some(h) if h.eq_ignore_ascii_case("github.com"))
        }
        Err(_) => false,
    }
}

/// Fetches every remote (pruning deleted remote branches).
pub fn fetch_all(path: String, auth: AuthOptions) -> CoreResult<FetchResult> {
    let repo = open_repo(&path)?;
    let mut names = vec![];
    let mut received = 0u32;
    for name in repo.remotes()?.iter().flatten() {
        let mut remote = repo.find_remote(name)?;
        let mut fo = FetchOptions::new();
        fo.remote_callbacks(callbacks(&auth, repo.config()?));
        fo.prune(git2::FetchPrune::On);
        fo.download_tags(git2::AutotagOption::Auto);
        remote.fetch(&[] as &[&str], Some(&mut fo), None)?;
        received += remote.stats().received_objects() as u32;
        names.push(name.to_string());
    }
    Ok(FetchResult {
        remotes: names,
        received_objects: received,
    })
}

/// Remote name and branch name the current branch tracks.
fn upstream_of(repo: &Repository, branch: &str) -> CoreResult<(String, String)> {
    let local = repo.find_branch(branch, BranchType::Local)?;
    let up = local.upstream().map_err(|_| CoreError::NoUpstream {
        branch: branch.to_string(),
    })?;
    let up_ref = up.get().name().unwrap_or_default().to_string();
    let remote = repo.branch_remote_name(&up_ref)?;
    Ok((remote.as_str().unwrap_or("origin").to_string(), up_ref))
}

/// Fetches the upstream of the current branch and integrates it using `strategy`.
pub fn pull(path: String, strategy: PullStrategy, auth: AuthOptions) -> CoreResult<PullResult> {
    let repo = open_repo(&path)?;
    util::workdir(&repo)?;
    let conflicts = util::conflicted_paths(&repo)?;
    if !conflicts.is_empty() {
        return Err(CoreError::Conflicts { files: conflicts });
    }
    let branch = util::current_branch(&repo)?;
    let (remote_name, up_ref) = upstream_of(&repo, &branch)?;

    let mut remote = repo.find_remote(&remote_name)?;
    let mut fo = FetchOptions::new();
    fo.remote_callbacks(callbacks(&auth, repo.config()?));
    remote.fetch(&[] as &[&str], Some(&mut fo), None)?;

    let up_oid = repo.refname_to_id(&up_ref)?;
    let upstream = repo.find_annotated_commit(up_oid)?;
    let head_oid = repo.head().ok().and_then(|h| h.target());
    let new_commits = match head_oid {
        Some(h) => repo.graph_ahead_behind(h, up_oid)?.1 as u32,
        None => 0,
    };

    let (analysis, _) = repo.merge_analysis(&[&upstream])?;
    if analysis.is_up_to_date() {
        return Ok(PullResult {
            outcome: PullOutcome::UpToDate,
            new_commits: 0,
        });
    }
    if analysis.is_fast_forward() || analysis.is_unborn() {
        fast_forward(&repo, &branch, up_oid)?;
        return Ok(PullResult {
            outcome: PullOutcome::FastForwarded,
            new_commits,
        });
    }
    match strategy {
        PullStrategy::FastForwardOnly => Err(CoreError::NotFastForward),
        PullStrategy::Merge => {
            merge_upstream(&repo, &branch, &up_ref, &upstream)?;
            Ok(PullResult {
                outcome: PullOutcome::Merged,
                new_commits,
            })
        }
        PullStrategy::Rebase => {
            rebase_onto(&repo, &upstream)?;
            Ok(PullResult {
                outcome: PullOutcome::Rebased,
                new_commits,
            })
        }
    }
}

fn fast_forward(repo: &Repository, branch: &str, target: git2::Oid) -> CoreResult<()> {
    let obj = repo.find_object(target, None)?;
    let mut cb = git2::build::CheckoutBuilder::new();
    cb.safe();
    repo.checkout_tree(&obj, Some(&mut cb))?;
    let refname = format!("refs/heads/{branch}");
    match repo.find_reference(&refname) {
        Ok(mut r) => {
            r.set_target(target, "pull: fast-forward")?;
        }
        Err(_) => {
            repo.reference(&refname, target, true, "pull: fast-forward")?;
        }
    }
    switch_to(repo, branch)
}

fn merge_upstream(
    repo: &Repository,
    branch: &str,
    up_ref: &str,
    upstream: &AnnotatedCommit,
) -> CoreResult<()> {
    let mut cb = git2::build::CheckoutBuilder::new();
    cb.safe().allow_conflicts(true).conflict_style_merge(true);
    repo.merge(&[upstream], None, Some(&mut cb))?;
    let conflicts = util::conflicted_paths(repo)?;
    if !conflicts.is_empty() {
        // Leave the merge in progress so the user can resolve and commit.
        return Err(CoreError::Conflicts { files: conflicts });
    }
    let sig = repo.signature().map_err(|_| CoreError::MissingIdentity)?;
    let mut index = repo.index()?;
    let tree = repo.find_tree(index.write_tree()?)?;
    let head = repo.head()?.peel_to_commit()?;
    let theirs = repo.find_commit(upstream.id())?;
    let short_up = up_ref.trim_start_matches("refs/remotes/");
    let msg = format!("Merge branch '{short_up}' into {branch}");
    repo.commit(Some("HEAD"), &sig, &sig, &msg, &tree, &[&head, &theirs])?;
    repo.cleanup_state()?;
    Ok(())
}

fn rebase_onto(repo: &Repository, upstream: &AnnotatedCommit) -> CoreResult<()> {
    let sig = repo.signature().map_err(|_| CoreError::MissingIdentity)?;
    let mut rebase = repo.rebase(None, Some(upstream), None, None)?;
    while let Some(op) = rebase.next() {
        let op = op?;
        let index = repo.index()?;
        if index.has_conflicts() {
            let files = util::conflicted_paths(repo)?;
            // Abort so the repository is left exactly as it was before the pull.
            rebase.abort()?;
            return Err(CoreError::Conflicts { files });
        }
        let original = repo.find_commit(op.id())?;
        let author = original.author();
        match rebase.commit(Some(&author), &sig, None) {
            Ok(_) => {}
            // The commit became empty (already upstream); skip it.
            Err(e) if e.code() == git2::ErrorCode::Applied => {}
            Err(e) => {
                rebase.abort()?;
                return Err(e.into());
            }
        }
    }
    rebase.finish(Some(&sig))?;
    Ok(())
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PushResult {
    pub remote: String,
    pub branch: String,
    /// True when this push also set the branch's upstream.
    pub set_upstream: bool,
}

/// Pushes the current branch to its upstream, or to `origin` with the same
/// name (setting the upstream) when it has none yet.
pub fn push(path: String, auth: AuthOptions) -> CoreResult<PushResult> {
    let repo = open_repo(&path)?;
    let branch = util::current_branch(&repo)?;
    let (remote_name, remote_branch, set_upstream) = match upstream_of(&repo, &branch) {
        Ok((remote, up_ref)) => {
            let prefix = format!("refs/remotes/{remote}/");
            let rb = up_ref.trim_start_matches(&prefix).to_string();
            (remote, rb, false)
        }
        Err(CoreError::NoUpstream { .. }) => {
            if repo.find_remote("origin").is_err() {
                return Err(CoreError::InvalidInput {
                    message: "this repository has no remote named origin".into(),
                });
            }
            ("origin".to_string(), branch.clone(), true)
        }
        Err(e) => return Err(e),
    };

    let mut remote = repo.find_remote(&remote_name)?;
    let rejection = std::cell::RefCell::new(None::<String>);
    {
        let mut cb = callbacks(&auth, repo.config()?);
        cb.push_update_reference(|refname, status| {
            if let Some(msg) = status {
                *rejection.borrow_mut() = Some(format!("{refname}: {msg}"));
            }
            Ok(())
        });
        let mut po = PushOptions::new();
        po.remote_callbacks(cb);
        let spec = format!("refs/heads/{branch}:refs/heads/{remote_branch}");
        remote
            .push(&[spec.as_str()], Some(&mut po))
            .map_err(|e| match CoreError::from(e) {
                CoreError::NotFastForward => CoreError::PushRejected {
                    message: "the remote has commits you don't have; pull first".into(),
                },
                other => other,
            })?;
    }
    if let Some(message) = rejection.into_inner() {
        return Err(CoreError::PushRejected { message });
    }
    if set_upstream {
        // Make sure the remote-tracking ref exists, then link it.
        let tracking = format!("refs/remotes/{remote_name}/{remote_branch}");
        let oid = repo.refname_to_id(&format!("refs/heads/{branch}"))?;
        repo.reference(&tracking, oid, true, "push: create tracking ref")?;
        let mut local = repo.find_branch(&branch, BranchType::Local)?;
        local.set_upstream(Some(&format!("{remote_name}/{remote_branch}")))?;
    } else {
        let tracking = format!("refs/remotes/{remote_name}/{remote_branch}");
        let oid = repo.refname_to_id(&format!("refs/heads/{branch}"))?;
        repo.reference(&tracking, oid, true, "push: update tracking ref")?;
    }
    Ok(PushResult {
        remote: remote_name,
        branch: remote_branch,
        set_upstream,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::branches::create_branch;
    use crate::api::repo::repo_status;
    use crate::util::testutil::*;

    fn no_auth() -> AuthOptions {
        AuthOptions::default()
    }

    #[test]
    fn token_only_for_github() {
        assert!(is_github_url("https://github.com/a/b.git"));
        assert!(is_github_url("https://GitHub.com/a/b"));
        assert!(!is_github_url("http://github.com/a/b"));
        assert!(!is_github_url("https://github.com.evil.io/a/b"));
        assert!(!is_github_url("https://gitlab.com/a/b"));
        assert!(!is_github_url("git@github.com:a/b.git"));
    }

    #[test]
    fn fetch_updates_behind_count() {
        let pair = RemotePair::new();
        let other = pair.other_clone();
        other.commit_file("x.txt", "x", "remote work");
        push_head(&other);
        let r = fetch_all(pair.local.path(), no_auth()).unwrap();
        assert_eq!(r.remotes, vec!["origin"]);
        assert_eq!(repo_status(pair.local.path()).unwrap().behind, 1);
    }

    #[test]
    fn pull_up_to_date() {
        let pair = RemotePair::new();
        let r = pull(pair.local.path(), PullStrategy::FastForwardOnly, no_auth()).unwrap();
        assert_eq!(r.outcome, PullOutcome::UpToDate);
    }

    #[test]
    fn pull_fast_forwards() {
        let pair = RemotePair::new();
        let other = pair.other_clone();
        other.commit_file("x.txt", "x", "remote work");
        push_head(&other);
        let r = pull(pair.local.path(), PullStrategy::FastForwardOnly, no_auth()).unwrap();
        assert_eq!(r.outcome, PullOutcome::FastForwarded);
        assert_eq!(r.new_commits, 1);
        assert!(pair.local.dir.path().join("x.txt").exists());
        let st = repo_status(pair.local.path()).unwrap();
        assert_eq!((st.ahead, st.behind), (0, 0));
        assert!(st.files.is_empty());
    }

    fn diverge(pair: &RemotePair) {
        let other = pair.other_clone();
        other.commit_file("theirs.txt", "t", "theirs");
        push_head(&other);
        pair.local.commit_file("mine.txt", "m", "mine");
    }

    #[test]
    fn ff_only_refuses_diverged() {
        let pair = RemotePair::new();
        diverge(&pair);
        let err = pull(pair.local.path(), PullStrategy::FastForwardOnly, no_auth()).unwrap_err();
        assert!(matches!(err, CoreError::NotFastForward));
    }

    #[test]
    fn merge_creates_merge_commit() {
        let pair = RemotePair::new();
        diverge(&pair);
        let r = pull(pair.local.path(), PullStrategy::Merge, no_auth()).unwrap();
        assert_eq!(r.outcome, PullOutcome::Merged);
        let head = pair.local.repo.head().unwrap().peel_to_commit().unwrap();
        assert_eq!(head.parent_count(), 2);
        assert!(pair.local.dir.path().join("theirs.txt").exists());
        assert_eq!(pair.local.repo.state(), git2::RepositoryState::Clean);
    }

    #[test]
    fn rebase_replays_local_commits() {
        let pair = RemotePair::new();
        diverge(&pair);
        let r = pull(pair.local.path(), PullStrategy::Rebase, no_auth()).unwrap();
        assert_eq!(r.outcome, PullOutcome::Rebased);
        let head = pair.local.repo.head().unwrap().peel_to_commit().unwrap();
        assert_eq!(head.summary(), Some("mine"));
        assert_eq!(head.parent(0).unwrap().summary(), Some("theirs"));
        assert_eq!(pair.local.repo.head().unwrap().shorthand(), Some("main"));
        let st = repo_status(pair.local.path()).unwrap();
        assert_eq!((st.ahead, st.behind), (1, 0));
    }

    #[test]
    fn merge_conflict_is_reported_and_left_for_user() {
        let pair = RemotePair::new();
        let other = pair.other_clone();
        other.commit_file("README.md", "theirs\n", "theirs");
        push_head(&other);
        pair.local.commit_file("README.md", "mine\n", "mine");
        let err = pull(pair.local.path(), PullStrategy::Merge, no_auth()).unwrap_err();
        match err {
            CoreError::Conflicts { files } => assert_eq!(files, vec!["README.md"]),
            other => panic!("unexpected {other:?}"),
        }
        assert_eq!(pair.local.repo.state(), git2::RepositoryState::Merge);
    }

    #[test]
    fn rebase_conflict_aborts_cleanly() {
        let pair = RemotePair::new();
        let other = pair.other_clone();
        other.commit_file("README.md", "theirs\n", "theirs");
        push_head(&other);
        let mine = pair.local.commit_file("README.md", "mine\n", "mine");
        let err = pull(pair.local.path(), PullStrategy::Rebase, no_auth()).unwrap_err();
        assert!(matches!(err, CoreError::Conflicts { .. }));
        assert_eq!(pair.local.repo.state(), git2::RepositoryState::Clean);
        assert_eq!(pair.local.repo.head().unwrap().target(), Some(mine));
    }

    #[test]
    fn push_sends_commits() {
        let pair = RemotePair::new();
        let oid = pair.local.commit_file("new.txt", "n", "local work");
        let r = push(pair.local.path(), no_auth()).unwrap();
        assert_eq!((r.remote.as_str(), r.branch.as_str()), ("origin", "main"));
        assert!(!r.set_upstream);
        let remote = Repository::open_bare(pair.remote_dir.path()).unwrap();
        assert_eq!(remote.refname_to_id("refs/heads/main").unwrap(), oid);
        assert_eq!(repo_status(pair.local.path()).unwrap().ahead, 0);
    }

    #[test]
    fn push_new_branch_sets_upstream() {
        let pair = RemotePair::new();
        create_branch(pair.local.path(), "feature".into(), None, true).unwrap();
        pair.local.commit_file("f.txt", "f", "feature work");
        let r = push(pair.local.path(), no_auth()).unwrap();
        assert!(r.set_upstream);
        let st = repo_status(pair.local.path()).unwrap();
        assert_eq!(st.upstream.as_deref(), Some("origin/feature"));
        assert_eq!(st.ahead, 0);
    }

    #[test]
    fn push_rejected_when_behind() {
        let pair = RemotePair::new();
        diverge(&pair);
        let err = push(pair.local.path(), no_auth()).unwrap_err();
        assert!(matches!(err, CoreError::PushRejected { .. }), "{err:?}");
    }

    #[test]
    fn pull_without_upstream_is_explained() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "a", "init");
        let err = pull(t.path(), PullStrategy::Merge, no_auth()).unwrap_err();
        assert!(matches!(err, CoreError::NoUpstream { .. }));
    }
}
