use std::collections::HashMap;

use git2::{Oid, Sort};

use crate::error::{CoreError, CoreResult};
use crate::util::{self, open_repo};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommitInfo {
    pub oid: String,
    pub short_oid: String,
    pub summary: String,
    pub message: String,
    pub author_name: String,
    pub author_email: String,
    /// Seconds since the Unix epoch.
    pub time: i64,
    pub parents: Vec<String>,
    /// Branch and tag names pointing at this commit, e.g. `main`, `origin/main`, `v1.0`.
    pub refs: Vec<String>,
}

/// One page of history, newest first. `start` is a branch, tag or commit id;
/// None means HEAD. With `all_branches`, every local and remote branch is
/// walked together (what a branch graph needs).
pub fn log_page(
    path: String,
    start: Option<String>,
    all_branches: bool,
    skip: u32,
    limit: u32,
) -> CoreResult<Vec<CommitInfo>> {
    let repo = open_repo(&path)?;
    if repo.head().is_err() && start.is_none() && !all_branches {
        return Ok(vec![]); // no commits yet
    }
    let mut walk = repo.revwalk()?;
    walk.set_sorting(Sort::TOPOLOGICAL | Sort::TIME)?;
    if all_branches {
        walk.push_glob("refs/heads/*")?;
        walk.push_glob("refs/remotes/*")?;
        if repo.head().is_ok() {
            walk.push_head()?;
        }
    } else if let Some(s) = start {
        let oid = repo
            .revparse_single(&s)
            .map_err(|_| CoreError::InvalidInput {
                message: format!("unknown revision {s}"),
            })?
            .peel_to_commit()?
            .id();
        walk.push(oid)?;
    } else {
        walk.push_head()?;
    }

    let refs = ref_names(&repo)?;
    let mut out = Vec::with_capacity(limit as usize);
    for oid in walk.skip(skip as usize).take(limit.min(2000) as usize) {
        let oid = oid?;
        let c = repo.find_commit(oid)?;
        let author = c.author();
        out.push(CommitInfo {
            oid: oid.to_string(),
            short_oid: util::short_oid(oid),
            summary: c.summary().unwrap_or_default().to_string(),
            message: c.message().unwrap_or_default().to_string(),
            author_name: author.name().unwrap_or_default().to_string(),
            author_email: author.email().unwrap_or_default().to_string(),
            time: c.time().seconds(),
            parents: c.parent_ids().map(|p| p.to_string()).collect(),
            refs: refs.get(&oid).cloned().unwrap_or_default(),
        });
    }
    Ok(out)
}

fn ref_names(repo: &git2::Repository) -> CoreResult<HashMap<Oid, Vec<String>>> {
    let mut map: HashMap<Oid, Vec<String>> = HashMap::new();
    for r in repo.references()?.flatten() {
        let Some(name) = r.shorthand().map(str::to_string) else {
            continue;
        };
        if name.ends_with("/HEAD") || r.is_note() {
            continue;
        }
        if let Ok(commit) = r.peel_to_commit() {
            map.entry(commit.id()).or_default().push(name);
        }
    }
    for v in map.values_mut() {
        v.sort();
    }
    Ok(map)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::util::testutil::*;

    #[test]
    fn pages_through_history_with_refs() {
        let t = TestRepo::new("main");
        let first = t.commit_file("a.txt", "1", "first");
        t.commit_file("a.txt", "2", "second");
        let third = t.commit_file("a.txt", "3", "third");
        t.repo
            .tag_lightweight("v1", &t.repo.find_object(third, None).unwrap(), false)
            .unwrap();

        let page = log_page(t.path(), None, false, 0, 2).unwrap();
        assert_eq!(page.len(), 2);
        assert_eq!(page[0].summary, "third");
        assert_eq!(page[0].refs, vec!["main", "v1"]);
        assert_eq!(page[0].parents.len(), 1);

        let rest = log_page(t.path(), None, false, 2, 10).unwrap();
        assert_eq!(rest.len(), 1);
        assert_eq!(rest[0].oid, first.to_string());
        assert!(rest[0].parents.is_empty());
    }

    #[test]
    fn empty_repo_has_no_history() {
        let t = TestRepo::new("main");
        assert!(log_page(t.path(), None, false, 0, 10).unwrap().is_empty());
    }

    #[test]
    fn all_branches_includes_side_branch() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "1", "base");
        let head = t.repo.head().unwrap().peel_to_commit().unwrap();
        t.repo.branch("side", &head, false).unwrap();
        crate::api::branches::checkout_branch(t.path(), "side".into()).unwrap();
        t.commit_file("s.txt", "s", "side work");
        crate::api::branches::checkout_branch(t.path(), "main".into()).unwrap();
        let only_head = log_page(t.path(), None, false, 0, 10).unwrap();
        assert_eq!(only_head.len(), 1);
        let all = log_page(t.path(), None, true, 0, 10).unwrap();
        assert_eq!(all.len(), 2);
    }
}
