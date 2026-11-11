use std::path::Path;

use git2::{DiffOptions, Oid, Repository};

use crate::error::{CoreError, CoreResult};
use crate::util::{self, open_repo};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LineKind {
    Context,
    Added,
    Removed,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DiffLine {
    pub kind: LineKind,
    pub old_lineno: Option<u32>,
    pub new_lineno: Option<u32>,
    /// Line text without the trailing newline.
    pub content: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DiffHunk {
    /// The `@@ -a,b +c,d @@` header.
    pub header: String,
    pub lines: Vec<DiffLine>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FileDiff {
    pub path: String,
    pub old_path: Option<String>,
    pub is_binary: bool,
    /// True when the diff was cut short because it was very large.
    pub truncated: bool,
    pub additions: u32,
    pub deletions: u32,
    pub hunks: Vec<DiffHunk>,
}

/// Lines kept per file before a diff is truncated, so huge generated files
/// cannot freeze the UI.
const MAX_DIFF_LINES: usize = 20_000;

/// Diff of one file: staged (HEAD → index) or unstaged (index → working tree).
pub fn diff_file(path: String, file: String, staged: bool) -> CoreResult<FileDiff> {
    let repo = open_repo(&path)?;
    util::workdir(&repo)?;
    let mut opts = DiffOptions::new();
    opts.pathspec(&file)
        .disable_pathspec_match(true)
        .include_untracked(true)
        .recurse_untracked_dirs(true)
        .show_untracked_content(true)
        .context_lines(3);
    let diff = if staged {
        let head_tree = head_tree(&repo)?;
        repo.diff_tree_to_index(head_tree.as_ref(), None, Some(&mut opts))?
    } else {
        repo.diff_index_to_workdir(None, Some(&mut opts))?
    };
    let mut files = collect_diffs(&diff)?;
    Ok(files.pop().unwrap_or(FileDiff {
        path: file,
        old_path: None,
        is_binary: false,
        truncated: false,
        additions: 0,
        deletions: 0,
        hunks: vec![],
    }))
}

/// Every file changed by a commit, compared with its first parent.
pub fn commit_diff(path: String, oid: String) -> CoreResult<Vec<FileDiff>> {
    let repo = open_repo(&path)?;
    let oid = Oid::from_str(&oid).map_err(|_| CoreError::InvalidInput {
        message: format!("not a commit id: {oid}"),
    })?;
    let commit = repo.find_commit(oid)?;
    let tree = commit.tree()?;
    let parent_tree = match commit.parent(0) {
        Ok(p) => Some(p.tree()?),
        Err(_) => None,
    };
    let mut opts = DiffOptions::new();
    opts.context_lines(3);
    let mut diff = repo.diff_tree_to_tree(parent_tree.as_ref(), Some(&tree), Some(&mut opts))?;
    diff.find_similar(None)?;
    collect_diffs(&diff)
}

fn head_tree(repo: &Repository) -> CoreResult<Option<git2::Tree<'_>>> {
    match repo.head() {
        Ok(head) => Ok(Some(head.peel_to_tree()?)),
        Err(e) if e.code() == git2::ErrorCode::UnbornBranch => Ok(None),
        Err(e) => Err(e.into()),
    }
}

fn collect_diffs(diff: &git2::Diff) -> CoreResult<Vec<FileDiff>> {
    let mut out = vec![];
    for idx in 0..diff.deltas().len() {
        let Some(patch) = git2::Patch::from_diff(diff, idx)? else {
            continue;
        };
        let delta = patch.delta();
        let new_path = delta
            .new_file()
            .path()
            .or(delta.old_file().path())
            .map(|p| p.to_string_lossy().into_owned())
            .unwrap_or_default();
        let old_path = delta
            .old_file()
            .path()
            .map(|p| p.to_string_lossy().into_owned())
            .filter(|p| *p != new_path);
        let is_binary = delta.flags().is_binary()
            || delta.new_file().is_binary()
            || delta.old_file().is_binary();

        let mut file = FileDiff {
            path: new_path,
            old_path,
            is_binary,
            truncated: false,
            additions: 0,
            deletions: 0,
            hunks: vec![],
        };
        if !is_binary {
            let (_, adds, dels) = patch.line_stats()?;
            file.additions = adds as u32;
            file.deletions = dels as u32;
            let mut total = 0usize;
            'hunks: for h in 0..patch.num_hunks() {
                let (hunk, n_lines) = patch.hunk(h)?;
                let mut lines = Vec::with_capacity(n_lines);
                for l in 0..n_lines {
                    if total >= MAX_DIFF_LINES {
                        file.truncated = true;
                        file.hunks.push(DiffHunk {
                            header: header_of(&hunk),
                            lines,
                        });
                        break 'hunks;
                    }
                    let line = patch.line_in_hunk(h, l)?;
                    let kind = match line.origin() {
                        '+' => LineKind::Added,
                        '-' => LineKind::Removed,
                        ' ' => LineKind::Context,
                        _ => continue, // "\ No newline at end of file" markers
                    };
                    let content = String::from_utf8_lossy(line.content());
                    lines.push(DiffLine {
                        kind,
                        old_lineno: line.old_lineno(),
                        new_lineno: line.new_lineno(),
                        content: content.trim_end_matches(['\n', '\r']).to_string(),
                    });
                    total += 1;
                }
                file.hunks.push(DiffHunk {
                    header: header_of(&hunk),
                    lines,
                });
            }
        }
        out.push(file);
    }
    Ok(out)
}

fn header_of(hunk: &git2::DiffHunk) -> String {
    String::from_utf8_lossy(hunk.header())
        .trim_end()
        .to_string()
}

/// Stages the given paths (new, modified or deleted files).
pub fn stage_paths(path: String, files: Vec<String>) -> CoreResult<()> {
    let repo = open_repo(&path)?;
    let workdir = util::workdir(&repo)?.to_path_buf();
    let mut index = repo.index()?;
    for f in &files {
        let rel = Path::new(f);
        if workdir.join(rel).exists() {
            index.add_path(rel)?;
        } else {
            index.remove_path(rel)?;
        }
    }
    index.write()?;
    Ok(())
}

/// Stages every change in the working tree, like `git add -A`.
pub fn stage_all(path: String) -> CoreResult<()> {
    let repo = open_repo(&path)?;
    util::workdir(&repo)?;
    stage_all_in(&repo)
}

fn stage_all_in(repo: &Repository) -> CoreResult<()> {
    let mut index = repo.index()?;
    index.add_all(["*"], git2::IndexAddOption::DEFAULT, None)?;
    index.update_all(["*"], None)?;
    index.write()?;
    Ok(())
}

/// Moves the given paths out of the index back to their HEAD version.
pub fn unstage_paths(path: String, files: Vec<String>) -> CoreResult<()> {
    let repo = open_repo(&path)?;
    match repo.head() {
        Ok(head) => {
            let obj = head.peel(git2::ObjectType::Commit)?;
            repo.reset_default(Some(&obj), files.iter())?;
        }
        Err(e) if e.code() == git2::ErrorCode::UnbornBranch => {
            let mut index = repo.index()?;
            for f in &files {
                index.remove_path(Path::new(f))?;
            }
            index.write()?;
        }
        Err(e) => return Err(e.into()),
    }
    Ok(())
}

/// Throws away unstaged changes to the given paths. Untracked files are deleted.
/// The UI must confirm with the user first: this cannot be undone.
pub fn discard_paths(path: String, files: Vec<String>) -> CoreResult<()> {
    let repo = open_repo(&path)?;
    let workdir = util::workdir(&repo)?.to_path_buf();
    let index = repo.index()?;
    let mut tracked = vec![];
    for f in &files {
        if index.get_path(Path::new(f), 0).is_some() {
            tracked.push(f.clone());
        } else {
            let full = workdir.join(f);
            // Never delete anything outside the working tree.
            if full.starts_with(&workdir) && full.is_file() {
                std::fs::remove_file(full)?;
            }
        }
    }
    if !tracked.is_empty() {
        let mut cb = git2::build::CheckoutBuilder::new();
        cb.force();
        for f in &tracked {
            cb.path(f);
        }
        repo.checkout_index(None, Some(&mut cb))?;
    }
    Ok(())
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommitResult {
    pub oid: String,
    pub short_oid: String,
    pub summary: String,
}

/// Creates a commit from the index. With `stage_all_first` every change is
/// staged first. Fails with `NothingToCommit` when the result would be
/// identical to HEAD (unless amending).
pub fn commit(
    path: String,
    message: String,
    stage_all_first: bool,
    amend: bool,
) -> CoreResult<CommitResult> {
    let mut repo = open_repo(&path)?;
    util::workdir(&repo)?;
    let merging = repo.state() == git2::RepositoryState::Merge;
    let mut merge_heads = vec![];
    if merging {
        repo.mergehead_foreach(|oid| {
            merge_heads.push(*oid);
            true
        })?;
    }
    let message = message.trim().to_string();
    if message.is_empty() {
        return Err(CoreError::InvalidInput {
            message: "commit message is empty".into(),
        });
    }
    let conflicts = util::conflicted_paths(&repo)?;
    if !conflicts.is_empty() {
        return Err(CoreError::Conflicts { files: conflicts });
    }
    if stage_all_first {
        stage_all_in(&repo)?;
    }

    let mut index = repo.index()?;
    let tree_oid = index.write_tree()?;
    let tree = repo.find_tree(tree_oid)?;
    let head_commit = match repo.head() {
        Ok(h) => Some(h.peel_to_commit()?),
        Err(e) if e.code() == git2::ErrorCode::UnbornBranch => None,
        Err(e) => return Err(e.into()),
    };
    let unchanged = match &head_commit {
        Some(c) => c.tree_id() == tree_oid,
        None => tree.is_empty(),
    };
    if unchanged && !amend && !merging {
        return Err(CoreError::NothingToCommit);
    }

    let sig = repo.signature().map_err(|_| CoreError::MissingIdentity)?;
    let oid = if amend {
        let head = head_commit.ok_or_else(|| CoreError::InvalidInput {
            message: "there is no commit to amend".into(),
        })?;
        head.amend(
            Some("HEAD"),
            None,
            Some(&sig),
            None,
            Some(&message),
            Some(&tree),
        )?
    } else {
        let mut parents = vec![];
        if let Some(c) = head_commit {
            parents.push(c);
        }
        for oid in &merge_heads {
            parents.push(repo.find_commit(*oid)?);
        }
        let refs: Vec<&git2::Commit> = parents.iter().collect();
        repo.commit(Some("HEAD"), &sig, &sig, &message, &tree, &refs)?
    };
    if merging {
        repo.cleanup_state()?;
    }
    Ok(CommitResult {
        oid: oid.to_string(),
        short_oid: util::short_oid(oid),
        summary: message.lines().next().unwrap_or_default().to_string(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::repo::{repo_status, ChangeKind};
    use crate::util::testutil::*;

    #[test]
    fn unstaged_diff_shows_added_and_removed_lines() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "one\ntwo\nthree\n", "init");
        t.write("a.txt", "one\n2\nthree\n");
        let d = diff_file(t.path(), "a.txt".into(), false).unwrap();
        assert_eq!((d.additions, d.deletions), (1, 1));
        let lines = &d.hunks[0].lines;
        assert!(lines
            .iter()
            .any(|l| l.kind == LineKind::Removed && l.content == "two"));
        assert!(lines
            .iter()
            .any(|l| l.kind == LineKind::Added && l.content == "2" && l.new_lineno == Some(2)));
    }

    #[test]
    fn untracked_file_diff_is_all_additions() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "a\n", "init");
        t.write("new.txt", "x\ny\n");
        let d = diff_file(t.path(), "new.txt".into(), false).unwrap();
        assert_eq!(d.additions, 2);
    }

    #[test]
    fn staged_diff_on_unborn_branch() {
        let t = TestRepo::new("main");
        t.write("a.txt", "a\n");
        stage_paths(t.path(), vec!["a.txt".into()]).unwrap();
        let d = diff_file(t.path(), "a.txt".into(), true).unwrap();
        assert_eq!(d.additions, 1);
    }

    #[test]
    fn binary_files_are_flagged() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "a\n", "init");
        std::fs::write(t.dir.path().join("b.bin"), [0u8, 159, 146, 150, 0, 1]).unwrap();
        let d = diff_file(t.path(), "b.bin".into(), false).unwrap();
        assert!(d.is_binary);
    }

    #[test]
    fn stage_unstage_round_trip() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "a\n", "init");
        t.write("a.txt", "b\n");
        stage_paths(t.path(), vec!["a.txt".into()]).unwrap();
        let st = repo_status(t.path()).unwrap();
        assert_eq!(st.files[0].staged, Some(ChangeKind::Modified));
        assert_eq!(st.files[0].unstaged, None);
        unstage_paths(t.path(), vec!["a.txt".into()]).unwrap();
        let st = repo_status(t.path()).unwrap();
        assert_eq!(st.files[0].staged, None);
        assert_eq!(st.files[0].unstaged, Some(ChangeKind::Modified));
    }

    #[test]
    fn staging_a_deleted_file_records_the_deletion() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "a\n", "init");
        std::fs::remove_file(t.dir.path().join("a.txt")).unwrap();
        stage_paths(t.path(), vec!["a.txt".into()]).unwrap();
        let st = repo_status(t.path()).unwrap();
        assert_eq!(st.files[0].staged, Some(ChangeKind::Deleted));
    }

    #[test]
    fn discard_restores_tracked_and_removes_untracked() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "a\n", "init");
        t.write("a.txt", "changed\n");
        t.write("junk.txt", "junk\n");
        discard_paths(t.path(), vec!["a.txt".into(), "junk.txt".into()]).unwrap();
        assert_eq!(
            std::fs::read_to_string(t.dir.path().join("a.txt")).unwrap(),
            "a\n"
        );
        assert!(!t.dir.path().join("junk.txt").exists());
    }

    #[test]
    fn commit_without_changes_is_refused() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "a\n", "init");
        let err = commit(t.path(), "nothing".into(), false, false).unwrap_err();
        assert!(matches!(err, CoreError::NothingToCommit));
        // Unstaged changes alone do not count unless stage_all_first is set.
        t.write("a.txt", "b\n");
        let err = commit(t.path(), "still nothing".into(), false, false).unwrap_err();
        assert!(matches!(err, CoreError::NothingToCommit));
    }

    #[test]
    fn commit_on_empty_repo_with_nothing_staged_is_refused() {
        let t = TestRepo::new("main");
        let err = commit(t.path(), "x".into(), true, false).unwrap_err();
        assert!(matches!(err, CoreError::NothingToCommit));
    }

    #[test]
    fn empty_message_is_refused() {
        let t = TestRepo::new("main");
        t.write("a.txt", "a\n");
        let err = commit(t.path(), "   ".into(), true, false).unwrap_err();
        assert!(matches!(err, CoreError::InvalidInput { .. }));
    }

    #[test]
    fn commit_all_creates_commit_and_cleans_tree() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "a\n", "init");
        t.write("a.txt", "b\n");
        t.write("new.txt", "n\n");
        let r = commit(t.path(), "feat: change\n\nbody".into(), true, false).unwrap();
        assert_eq!(r.summary, "feat: change");
        let st = repo_status(t.path()).unwrap();
        assert!(st.files.is_empty());
        let head = t.repo.head().unwrap().peel_to_commit().unwrap();
        assert_eq!(head.id().to_string(), r.oid);
        assert_eq!(head.parent_count(), 1);
    }

    #[test]
    fn amend_rewrites_last_commit() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "a\n", "init");
        let r = commit(t.path(), "better message".into(), false, true).unwrap();
        let head = t.repo.head().unwrap().peel_to_commit().unwrap();
        assert_eq!(head.id().to_string(), r.oid);
        assert_eq!(head.summary(), Some("better message"));
        assert_eq!(head.parent_count(), 0);
    }

    #[test]
    fn commit_diff_lists_changed_files() {
        let t = TestRepo::new("main");
        t.commit_file("a.txt", "a\n", "init");
        let oid = t.commit_file("b.txt", "b\nc\n", "second");
        let files = commit_diff(t.path(), oid.to_string()).unwrap();
        assert_eq!(files.len(), 1);
        assert_eq!(files[0].path, "b.txt");
        assert_eq!(files[0].additions, 2);
    }
}
