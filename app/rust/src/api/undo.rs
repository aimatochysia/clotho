//! Undoing commits safely.
//!
//! The newest commit on a branch that has not been pushed is taken back: the
//! branch moves to its parent and the commit's changes stay staged, so nothing
//! is lost. Any other commit (pushed, or older) is cancelled with a new commit
//! that reverses it, so shared history is never rewritten and no force push
//! is ever needed. A taken-back commit is kept under `refs/clotho/backup/` so
//! it can be redone.

use git2::{Oid, Repository};

use crate::api::identity::{signature, Identity};
use crate::error::{CoreError, CoreResult};
use crate::util::{self, open_repo};

const BACKUP_PREFIX: &str = "refs/clotho/backup/";
/// Backups older than this are pruned on the next undo.
const BACKUP_DAYS: i64 = 30;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UndoKind {
    /// Move the branch back one commit; its changes return to Changes.
    TakeBack,
    /// Add a new commit that reverses this one.
    Cancel,
    /// This commit cannot be undone from the app (see `UndoPlan::reason`).
    Unsupported,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UndoPlan {
    pub kind: UndoKind,
    /// True when the commit is already on a remote.
    pub pushed: bool,
    /// Why the commit cannot be undone, when `kind` is Unsupported.
    pub reason: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UndoResult {
    pub kind: UndoKind,
    /// The cancelling commit (Cancel) or the new branch tip (TakeBack).
    pub head: String,
    /// The backup ref that `redo_undo` restores (TakeBack only).
    pub backup: Option<String>,
}

/// Works out how `oid` would be undone, without changing anything.
pub fn plan_undo(path: String, oid: String) -> CoreResult<UndoPlan> {
    let repo = open_repo(&path)?;
    plan(&repo, parse_oid(&oid)?)
}

fn plan(repo: &Repository, oid: Oid) -> CoreResult<UndoPlan> {
    let unsupported = |pushed: bool, why: &str| UndoPlan {
        kind: UndoKind::Unsupported,
        pushed,
        reason: Some(why.to_string()),
    };
    let commit = repo.find_commit(oid)?;
    let pushed = on_a_remote(repo, oid)?;
    if repo.head_detached()? {
        return Ok(unsupported(pushed, "Switch to a branch first."));
    }
    let head = repo.head()?.peel_to_commit()?.id();
    if head != oid && !repo.graph_descendant_of(head, oid)? {
        return Ok(unsupported(
            pushed,
            "This commit is not on the current branch. Switch to its branch first.",
        ));
    }
    if commit.parent_count() > 1 {
        return Ok(unsupported(pushed, "Undoing a merge is not supported yet."));
    }
    if commit.parent_count() == 0 {
        return Ok(unsupported(
            pushed,
            "This is the first commit of the repository, so there is nothing to go back to.",
        ));
    }
    let kind = if head == oid && !pushed {
        UndoKind::TakeBack
    } else {
        UndoKind::Cancel
    };
    Ok(UndoPlan {
        kind,
        pushed,
        reason: None,
    })
}

/// Undoes `oid` the way `plan_undo` describes. `identity` signs the
/// cancelling commit.
pub fn undo_commit(
    path: String,
    oid: String,
    identity: Option<Identity>,
) -> CoreResult<UndoResult> {
    let repo = open_repo(&path)?;
    util::workdir(&repo)?;
    if repo.state() != git2::RepositoryState::Clean {
        return Err(CoreError::InvalidInput {
            message: "Finish or abort the merge or rebase in progress first.".into(),
        });
    }
    let conflicts = util::conflicted_paths(&repo)?;
    if !conflicts.is_empty() {
        return Err(CoreError::Conflicts { files: conflicts });
    }
    let oid = parse_oid(&oid)?;
    let p = plan(&repo, oid)?;
    match p.kind {
        UndoKind::Unsupported => Err(CoreError::InvalidInput {
            message: p
                .reason
                .unwrap_or_else(|| "This commit cannot be undone.".into()),
        }),
        UndoKind::TakeBack => take_back(&repo, oid),
        UndoKind::Cancel => cancel(&repo, oid, identity.as_ref()),
    }
}

fn take_back(repo: &Repository, oid: Oid) -> CoreResult<UndoResult> {
    let commit = repo.find_commit(oid)?;
    let parent = commit.parent(0)?;
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or_default();
    prune_backups(repo, now)?;
    let name = format!("{BACKUP_PREFIX}{now}-{}", util::short_oid(oid));
    repo.reference(&name, oid, true, "clotho: backup before undo")?;
    // Soft reset: only the branch moves; index and files keep the changes.
    repo.reset(parent.as_object(), git2::ResetType::Soft, None)?;
    Ok(UndoResult {
        kind: UndoKind::TakeBack,
        head: parent.id().to_string(),
        backup: Some(name),
    })
}

fn cancel(repo: &Repository, oid: Oid, identity: Option<&Identity>) -> CoreResult<UndoResult> {
    let commit = repo.find_commit(oid)?;
    let head = repo.head()?.peel_to_commit()?;
    let mut index = repo.revert_commit(&commit, &head, 0, None)?;
    if index.has_conflicts() {
        return Err(CoreError::InvalidInput {
            message: "Later commits changed the same lines, so this commit cannot be cancelled automatically.".into(),
        });
    }
    let tree = repo.find_tree(index.write_tree_to(repo)?)?;
    if tree.id() == head.tree_id() {
        return Err(CoreError::InvalidInput {
            message: "Its changes are already gone; there is nothing to cancel.".into(),
        });
    }
    // Update the files first; this refuses to touch files with unsaved
    // changes, and leaves everything as it was when it does.
    let mut co = git2::build::CheckoutBuilder::new();
    co.safe();
    repo.checkout_tree(tree.as_object(), Some(&mut co))
        .map_err(|e| match e.code() {
            git2::ErrorCode::Conflict => CoreError::DirtyWorktree {
                message: "commit or discard your changes to the files this commit touched first"
                    .into(),
            },
            _ => e.into(),
        })?;
    let sig = signature(repo, identity)?;
    let summary = commit.summary().unwrap_or_default();
    let message = format!("Revert \"{summary}\"\n\nThis reverts commit {oid}.\n");
    let new = repo.commit(Some("HEAD"), &sig, &sig, &message, &tree, &[&head])?;
    Ok(UndoResult {
        kind: UndoKind::Cancel,
        head: new.to_string(),
        backup: None,
    })
}

/// Puts back a commit taken back by `undo_commit`. Only works while the
/// branch is still where the undo left it.
pub fn redo_undo(path: String, backup: String) -> CoreResult<String> {
    let repo = open_repo(&path)?;
    if !backup.starts_with(BACKUP_PREFIX) {
        return Err(CoreError::InvalidInput {
            message: "not an undo backup".into(),
        });
    }
    let saved = repo.find_reference(&backup)?.peel_to_commit()?;
    let head = repo.head()?.peel_to_commit()?;
    if saved.parent_id(0).ok() != Some(head.id()) {
        return Err(CoreError::InvalidInput {
            message: "New commits were made since the undo, so it can no longer be redone.".into(),
        });
    }
    repo.reset(saved.as_object(), git2::ResetType::Soft, None)?;
    repo.find_reference(&backup)?.delete()?;
    Ok(saved.id().to_string())
}

fn on_a_remote(repo: &Repository, oid: Oid) -> CoreResult<bool> {
    for r in repo.references_glob("refs/remotes/*")? {
        let r = r?;
        let Some(tip) = r.target() else { continue };
        if tip == oid || repo.graph_descendant_of(tip, oid)? {
            return Ok(true);
        }
    }
    Ok(false)
}

fn prune_backups(repo: &Repository, now: i64) -> CoreResult<()> {
    let cutoff = now - BACKUP_DAYS * 86_400;
    let mut old = vec![];
    for r in repo.references_glob(&format!("{BACKUP_PREFIX}*"))? {
        let r = r?;
        let stamp = r
            .name()
            .and_then(|n| n.strip_prefix(BACKUP_PREFIX))
            .and_then(|n| n.split('-').next())
            .and_then(|s| s.parse::<i64>().ok());
        if matches!(stamp, Some(t) if t < cutoff) {
            if let Some(n) = r.name() {
                old.push(n.to_string());
            }
        }
    }
    for n in old {
        repo.find_reference(&n)?.delete()?;
    }
    Ok(())
}

fn parse_oid(oid: &str) -> CoreResult<Oid> {
    Oid::from_str(oid).map_err(|_| CoreError::InvalidInput {
        message: format!("not a commit id: {oid}"),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::repo::repo_status;
    use crate::util::testutil::*;

    fn head(repo: &TestRepo) -> Oid {
        repo.repo.head().unwrap().target().unwrap()
    }

    #[test]
    fn unpushed_head_is_taken_back_and_redone() {
        let pair = RemotePair::new();
        let local = &pair.local;
        let base = head(local);
        let c = local.commit_file("a.txt", "new\n", "add a");
        let plan = plan_undo(local.path(), c.to_string()).unwrap();
        assert_eq!(plan.kind, UndoKind::TakeBack);
        assert!(!plan.pushed);

        let r = undo_commit(local.path(), c.to_string(), None).unwrap();
        assert_eq!(r.kind, UndoKind::TakeBack);
        assert_eq!(head(local), base);
        // The change is kept, staged, and the file is untouched.
        let st = repo_status(local.path()).unwrap();
        assert_eq!(st.staged_count, 1);
        assert_eq!(
            std::fs::read_to_string(local.dir.path().join("a.txt")).unwrap(),
            "new\n"
        );

        let backup = r.backup.unwrap();
        assert_eq!(
            redo_undo(local.path(), backup.clone()).unwrap(),
            c.to_string()
        );
        assert_eq!(head(local), c);
        assert!(local.repo.find_reference(&backup).is_err());
        assert_eq!(repo_status(local.path()).unwrap().staged_count, 0);
    }

    #[test]
    fn redo_refused_after_new_commit() {
        let pair = RemotePair::new();
        let local = &pair.local;
        let c = local.commit_file("a.txt", "new\n", "add a");
        let r = undo_commit(local.path(), c.to_string(), None).unwrap();
        local.commit_file("b.txt", "b\n", "other");
        assert!(redo_undo(local.path(), r.backup.unwrap()).is_err());
    }

    #[test]
    fn pushed_commit_is_cancelled_with_new_commit() {
        let pair = RemotePair::new();
        let local = &pair.local;
        let c = local.commit_file("a.txt", "new\n", "add a");
        push_head(local);
        let plan = plan_undo(local.path(), c.to_string()).unwrap();
        assert_eq!(plan.kind, UndoKind::Cancel);
        assert!(plan.pushed);

        let r = undo_commit(local.path(), c.to_string(), None).unwrap();
        assert_eq!(r.kind, UndoKind::Cancel);
        let new = local.repo.find_commit(head(local)).unwrap();
        assert_eq!(new.parent_id(0).unwrap(), c);
        assert!(new.message().unwrap().starts_with("Revert \"add a\""));
        assert!(!local.dir.path().join("a.txt").exists());
        let st = repo_status(local.path()).unwrap();
        assert!(st.files.is_empty());
        assert_eq!(st.ahead, 1);
    }

    #[test]
    fn older_commit_is_cancelled_keeping_later_work() {
        let t = TestRepo::new("main");
        t.commit_file("base.txt", "base\n", "base");
        let c = t.commit_file("a.txt", "a\n", "add a");
        t.commit_file("b.txt", "b\n", "add b");
        assert_eq!(
            plan_undo(t.path(), c.to_string()).unwrap().kind,
            UndoKind::Cancel
        );
        undo_commit(t.path(), c.to_string(), None).unwrap();
        assert!(!t.dir.path().join("a.txt").exists());
        assert!(t.dir.path().join("b.txt").exists());
    }

    #[test]
    fn cancel_refuses_to_touch_unsaved_changes() {
        let t = TestRepo::new("main");
        t.commit_file("base.txt", "base\n", "base");
        let c = t.commit_file("a.txt", "a\n", "add a");
        t.commit_file("b.txt", "b\n", "add b");
        t.write("a.txt", "edited\n");
        let before = head(&t);
        let e = undo_commit(t.path(), c.to_string(), None).unwrap_err();
        assert!(matches!(e, CoreError::DirtyWorktree { .. }), "{e:?}");
        assert_eq!(head(&t), before);
        assert_eq!(
            std::fs::read_to_string(t.dir.path().join("a.txt")).unwrap(),
            "edited\n"
        );
    }

    #[test]
    fn cancel_keeps_unrelated_unsaved_changes() {
        let t = TestRepo::new("main");
        t.commit_file("base.txt", "base\n", "base");
        let c = t.commit_file("a.txt", "a\n", "add a");
        t.commit_file("b.txt", "b\n", "add b");
        t.write("b.txt", "edited\n");
        undo_commit(t.path(), c.to_string(), None).unwrap();
        assert_eq!(
            std::fs::read_to_string(t.dir.path().join("b.txt")).unwrap(),
            "edited\n"
        );
    }

    #[test]
    fn conflicting_cancel_is_refused() {
        let t = TestRepo::new("main");
        t.commit_file("f.txt", "one\n", "base");
        let c = t.commit_file("f.txt", "two\n", "change");
        t.commit_file("f.txt", "three\n", "change again");
        let before = head(&t);
        assert!(undo_commit(t.path(), c.to_string(), None).is_err());
        assert_eq!(head(&t), before);
    }

    #[test]
    fn first_commit_and_other_branches_are_unsupported() {
        let t = TestRepo::new("main");
        let root = t.commit_file("f.txt", "one\n", "base");
        assert_eq!(
            plan_undo(t.path(), root.to_string()).unwrap().kind,
            UndoKind::Unsupported
        );
        assert!(undo_commit(t.path(), root.to_string(), None).is_err());
        crate::api::branches::create_branch(t.path(), "side".into(), None, true).unwrap();
        let side = t.commit_file("s.txt", "s\n", "side work");
        crate::api::branches::checkout_branch(t.path(), "main".into()).unwrap();
        let p = plan_undo(t.path(), side.to_string()).unwrap();
        assert_eq!(p.kind, UndoKind::Unsupported);
        assert!(p.reason.unwrap().contains("current branch"));
    }

    #[test]
    fn old_backups_are_pruned() {
        let t = TestRepo::new("main");
        let root = t.commit_file("f.txt", "one\n", "base");
        t.repo
            .reference("refs/clotho/backup/1000-abc", root, true, "old")
            .unwrap();
        let c = t.commit_file("g.txt", "g\n", "g");
        undo_commit(t.path(), c.to_string(), None).unwrap();
        assert!(t
            .repo
            .find_reference("refs/clotho/backup/1000-abc")
            .is_err());
    }
}
