use git2::{BranchType, Repository};

use crate::api::repo::upstream_counts;
use crate::error::{CoreError, CoreResult};
use crate::util::{self, open_repo};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BranchInfo {
    /// `main` for local branches, `origin/main` for remote-tracking ones.
    pub name: String,
    pub is_remote: bool,
    pub is_head: bool,
    pub upstream: Option<String>,
    pub ahead: u32,
    pub behind: u32,
    pub short_oid: String,
    pub summary: String,
    /// Commit time, seconds since the Unix epoch.
    pub time: i64,
}

/// Local branches first (current one on top), then remote-tracking branches.
pub fn list_branches(path: String) -> CoreResult<Vec<BranchInfo>> {
    let repo = open_repo(&path)?;
    let mut out = vec![];
    for item in repo.branches(None)? {
        let (branch, kind) = item?;
        let Some(name) = branch.name()?.map(str::to_string) else {
            continue;
        };
        // Skip symbolic refs such as origin/HEAD.
        if kind == BranchType::Remote && name.ends_with("/HEAD") {
            continue;
        }
        let Ok(commit) = branch.get().peel_to_commit() else {
            continue;
        };
        let (upstream, ahead, behind) = if kind == BranchType::Local {
            upstream_counts(&repo, &name)
        } else {
            (None, 0, 0)
        };
        out.push(BranchInfo {
            is_remote: kind == BranchType::Remote,
            is_head: branch.is_head(),
            upstream,
            ahead,
            behind,
            short_oid: util::short_oid(commit.id()),
            summary: commit.summary().unwrap_or_default().to_string(),
            time: commit.time().seconds(),
            name,
        });
    }
    out.sort_by(|a, b| (a.is_remote, !a.is_head, &a.name).cmp(&(b.is_remote, !b.is_head, &b.name)));
    Ok(out)
}

fn validate_name(name: &str) -> CoreResult<()> {
    if git2::Branch::name_is_valid(name)? {
        Ok(())
    } else {
        Err(CoreError::InvalidInput {
            message: format!("\"{name}\" is not a valid branch name"),
        })
    }
}

/// Checks out a local branch. Passing a remote branch such as `origin/feature`
/// creates (or reuses) a local `feature` tracking it. Refuses when local
/// changes would be overwritten.
pub fn checkout_branch(path: String, name: String) -> CoreResult<()> {
    let repo = open_repo(&path)?;
    util::workdir(&repo)?;
    let local_name = match repo.find_branch(&name, BranchType::Local) {
        Ok(_) => name.clone(),
        Err(_) => {
            let remote = repo.find_branch(&name, BranchType::Remote).map_err(|_| {
                CoreError::InvalidInput {
                    message: format!("no branch named {name}"),
                }
            })?;
            let short = name.split_once('/').map(|(_, b)| b).unwrap_or(&name);
            if repo.find_branch(short, BranchType::Local).is_err() {
                let commit = remote.get().peel_to_commit()?;
                let mut local = repo.branch(short, &commit, false)?;
                local.set_upstream(Some(&name))?;
            }
            short.to_string()
        }
    };
    switch_to(&repo, &local_name)
}

pub(crate) fn switch_to(repo: &Repository, local_name: &str) -> CoreResult<()> {
    let refname = format!("refs/heads/{local_name}");
    let target = repo.revparse_single(&refname)?;
    let mut cb = git2::build::CheckoutBuilder::new();
    cb.safe();
    repo.checkout_tree(&target, Some(&mut cb))?;
    repo.set_head(&refname)?;
    Ok(())
}

/// Creates a branch at `start_point` (a branch name or commit id; HEAD when
/// None) and optionally checks it out.
pub fn create_branch(
    path: String,
    name: String,
    start_point: Option<String>,
    checkout: bool,
) -> CoreResult<()> {
    let repo = open_repo(&path)?;
    validate_name(&name)?;
    if repo.find_branch(&name, BranchType::Local).is_ok() {
        return Err(CoreError::InvalidInput {
            message: format!("branch {name} already exists"),
        });
    }
    let commit = match start_point {
        Some(sp) => repo.revparse_single(&sp)?.peel_to_commit()?,
        None => repo.head()?.peel_to_commit()?,
    };
    repo.branch(&name, &commit, false)?;
    if checkout {
        switch_to(&repo, &name)?;
    }
    Ok(())
}

pub fn rename_branch(path: String, old_name: String, new_name: String) -> CoreResult<()> {
    let repo = open_repo(&path)?;
    validate_name(&new_name)?;
    let mut branch = repo.find_branch(&old_name, BranchType::Local)?;
    branch.rename(&new_name, false)?;
    Ok(())
}

/// Deletes a local branch. Without `force`, refuses when the branch has
/// commits that are in neither HEAD nor its own upstream.
pub fn delete_branch(path: String, name: String, force: bool) -> CoreResult<()> {
    let repo = open_repo(&path)?;
    let mut branch = repo.find_branch(&name, BranchType::Local)?;
    if branch.is_head() {
        return Err(CoreError::InvalidInput {
            message: "cannot delete the branch you are on".into(),
        });
    }
    if !force {
        let tip = branch.get().target().ok_or(CoreError::DetachedHead)?;
        let mut merged = false;
        if let Some(head) = repo.head().ok().and_then(|h| h.target()) {
            merged |= head == tip || repo.graph_descendant_of(head, tip)?;
        }
        if let Ok(up) = branch.upstream() {
            if let Some(up_oid) = up.get().target() {
                merged |= up_oid == tip || repo.graph_descendant_of(up_oid, tip)?;
            }
        }
        if !merged {
            return Err(CoreError::BranchNotMerged { name });
        }
    }
    branch.delete()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::util::testutil::*;

    #[test]
    fn lists_local_then_remote_with_head_first() {
        let pair = RemotePair::new();
        let p = pair.local.path();
        create_branch(p.clone(), "alpha".into(), None, false).unwrap();
        let list = list_branches(p).unwrap();
        let names: Vec<_> = list.iter().map(|b| b.name.as_str()).collect();
        assert_eq!(names, vec!["main", "alpha", "origin/main"]);
        assert!(list[0].is_head);
        assert_eq!(list[0].upstream.as_deref(), Some("origin/main"));
        assert!(list[2].is_remote);
    }

    #[test]
    fn create_and_checkout() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "a", "init");
        create_branch(t.path(), "feature/x".into(), None, true).unwrap();
        assert_eq!(t.repo.head().unwrap().shorthand(), Some("feature/x"));
        checkout_branch(t.path(), "main".into()).unwrap();
        assert_eq!(t.repo.head().unwrap().shorthand(), Some("main"));
    }

    #[test]
    fn invalid_or_duplicate_names_are_refused() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "a", "init");
        assert!(matches!(
            create_branch(t.path(), "bad name..".into(), None, false),
            Err(CoreError::InvalidInput { .. })
        ));
        assert!(matches!(
            create_branch(t.path(), "main".into(), None, false),
            Err(CoreError::InvalidInput { .. })
        ));
    }

    #[test]
    fn checkout_refuses_to_overwrite_local_changes() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "a", "init");
        create_branch(t.path(), "other".into(), None, true).unwrap();
        t.commit_file("a.txt", "other", "other change");
        checkout_branch(t.path(), "main".into()).unwrap();
        t.write("a.txt", "dirty");
        let err = checkout_branch(t.path(), "other".into()).unwrap_err();
        assert!(matches!(err, CoreError::DirtyWorktree { .. }), "{err:?}");
        assert_eq!(t.repo.head().unwrap().shorthand(), Some("main"));
    }

    #[test]
    fn checkout_remote_branch_creates_tracking_branch() {
        let pair = RemotePair::new();
        let other = pair.other_clone();
        let head = other.repo.head().unwrap().peel_to_commit().unwrap();
        other.repo.branch("topic", &head, false).unwrap();
        let mut remote = other.repo.find_remote("origin").unwrap();
        remote
            .push(&["refs/heads/topic:refs/heads/topic"], None)
            .unwrap();
        let mut origin = pair.local.repo.find_remote("origin").unwrap();
        origin.fetch(&[] as &[&str], None, None).unwrap();

        checkout_branch(pair.local.path(), "origin/topic".into()).unwrap();
        assert_eq!(pair.local.repo.head().unwrap().shorthand(), Some("topic"));
        let b = pair
            .local
            .repo
            .find_branch("topic", BranchType::Local)
            .unwrap();
        assert_eq!(b.upstream().unwrap().name().unwrap(), Some("origin/topic"));
    }

    #[test]
    fn delete_refuses_unmerged_unless_forced() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "a", "init");
        create_branch(t.path(), "wip".into(), None, true).unwrap();
        t.commit_file("b.txt", "b", "unmerged work");
        checkout_branch(t.path(), "main".into()).unwrap();
        let err = delete_branch(t.path(), "wip".into(), false).unwrap_err();
        assert!(matches!(err, CoreError::BranchNotMerged { .. }));
        delete_branch(t.path(), "wip".into(), true).unwrap();
        assert!(t.repo.find_branch("wip", BranchType::Local).is_err());
    }

    #[test]
    fn delete_merged_branch_and_refuse_current() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "a", "init");
        create_branch(t.path(), "done".into(), None, false).unwrap();
        delete_branch(t.path(), "done".into(), false).unwrap();
        assert!(matches!(
            delete_branch(t.path(), "main".into(), false),
            Err(CoreError::InvalidInput { .. })
        ));
    }

    #[test]
    fn rename_works() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "a", "init");
        create_branch(t.path(), "old".into(), None, false).unwrap();
        rename_branch(t.path(), "old".into(), "new".into()).unwrap();
        assert!(t.repo.find_branch("new", BranchType::Local).is_ok());
    }
}
