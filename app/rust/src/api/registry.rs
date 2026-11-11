use std::path::{Path, PathBuf};
use std::sync::Mutex;

use serde::{Deserialize, Serialize};

use crate::api::remote::PullStrategy;
use crate::api::repo::inspect_repo;
use crate::error::{CoreError, CoreResult};

/// App-wide defaults. Each repository can override pull and push behaviour.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default)]
pub struct AppSettings {
    pub pull_strategy: PullStrategy,
    /// Push automatically after every successful commit.
    pub push_after_commit: bool,
    /// How many folders deep "Scan folder" looks for repositories.
    pub scan_depth: u32,
    /// Check GitHub for a newer Clotho release on start.
    pub check_updates: bool,
    /// Folder the clone dialog suggests (the last one used).
    pub clone_dir: Option<String>,
}

impl Default for AppSettings {
    fn default() -> Self {
        AppSettings {
            pull_strategy: PullStrategy::FastForwardOnly,
            push_after_commit: false,
            scan_depth: 3,
            check_updates: true,
            clone_dir: None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RepoEntry {
    pub path: String,
    /// Display name; defaults to the folder name.
    pub name: String,
    /// Overrides `AppSettings::pull_strategy` when set.
    #[serde(default)]
    pub pull_strategy: Option<PullStrategy>,
    /// Overrides `AppSettings::push_after_commit` when set.
    #[serde(default)]
    pub push_after_commit: Option<bool>,
    /// When to fetch this repository automatically. Off unless turned on.
    #[serde(default = "FetchSchedule::off")]
    pub fetch_schedule: FetchSchedule,
    /// Unix seconds of the last automatic fetch; kept by the core, so
    /// whatever the app sends here in `update_repo` is ignored.
    #[serde(default)]
    pub last_auto_fetch: Option<i64>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum FetchUnit {
    Minutes,
    Hours,
    Days,
}

/// "Every `every` `unit`", for example every 2 hours.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct FetchSchedule {
    pub enabled: bool,
    pub every: u32,
    pub unit: FetchUnit,
}

/// Largest value accepted for `FetchSchedule::every`.
pub const MAX_FETCH_EVERY: u32 = 999;

impl FetchSchedule {
    #[flutter_rust_bridge::frb(ignore)]
    pub fn off() -> Self {
        FetchSchedule {
            enabled: false,
            every: 1,
            unit: FetchUnit::Hours,
        }
    }

    fn clamped(self) -> Self {
        FetchSchedule {
            every: self.every.clamp(1, MAX_FETCH_EVERY),
            ..self
        }
    }

    /// Seconds between fetches.
    #[flutter_rust_bridge::frb(ignore)]
    pub fn interval_seconds(&self) -> i64 {
        let unit = match self.unit {
            FetchUnit::Minutes => 60,
            FetchUnit::Hours => 3600,
            FetchUnit::Days => 86_400,
        };
        i64::from(self.every.max(1)) * unit
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Registry {
    #[serde(default)]
    pub settings: AppSettings,
    #[serde(default)]
    pub repos: Vec<RepoEntry>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AddReport {
    pub registry: Registry,
    pub added: Vec<String>,
    /// Paths skipped, with the reason (already added, not a repository, ...).
    pub skipped: Vec<SkippedPath>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SkippedPath {
    pub path: String,
    pub reason: String,
}

const FILE_NAME: &str = "clotho.json";

/// Serialises read-modify-write cycles on the registry file.
static LOCK: Mutex<()> = Mutex::new(());

fn file_in(config_dir: &str) -> PathBuf {
    Path::new(config_dir).join(FILE_NAME)
}

fn read(config_dir: &str) -> CoreResult<Registry> {
    let file = file_in(config_dir);
    match std::fs::read_to_string(&file) {
        Ok(text) => Ok(serde_json::from_str(&text)?),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(Registry {
            settings: AppSettings::default(),
            repos: vec![],
        }),
        Err(e) => Err(e.into()),
    }
}

/// Writes to a temporary file and renames it over the old one, so a crash
/// mid-write can never leave a half-written settings file.
fn write(config_dir: &str, registry: &Registry) -> CoreResult<()> {
    std::fs::create_dir_all(config_dir)?;
    let file = file_in(config_dir);
    let tmp = file.with_extension("json.tmp");
    std::fs::write(&tmp, serde_json::to_vec_pretty(registry)?)?;
    std::fs::rename(&tmp, &file)?;
    Ok(())
}

/// Loads the repository list and settings from `config_dir` (empty on first run).
pub fn load_registry(config_dir: String) -> CoreResult<Registry> {
    let _g = LOCK.lock().unwrap();
    read(&config_dir)
}

/// Adds repositories by path. Each must be a Git working tree; duplicates
/// (same path) are skipped.
pub fn add_repos(config_dir: String, paths: Vec<String>) -> CoreResult<AddReport> {
    let _g = LOCK.lock().unwrap();
    let mut reg = read(&config_dir)?;
    let mut added = vec![];
    let mut skipped = vec![];
    for p in paths {
        match inspect_repo(p.clone()) {
            Ok(info) if info.is_bare => skipped.push(SkippedPath {
                path: p,
                reason: "bare repositories have no files to manage".into(),
            }),
            Ok(info) => {
                if reg.repos.iter().any(|r| same_path(&r.path, &info.path)) {
                    skipped.push(SkippedPath {
                        path: info.path,
                        reason: "already in the list".into(),
                    });
                    continue;
                }
                let name = Path::new(&info.path)
                    .file_name()
                    .map(|n| n.to_string_lossy().into_owned())
                    .unwrap_or_else(|| info.path.clone());
                reg.repos.push(RepoEntry {
                    path: info.path.clone(),
                    name,
                    pull_strategy: None,
                    push_after_commit: None,
                    fetch_schedule: FetchSchedule::off(),
                    last_auto_fetch: None,
                });
                added.push(info.path);
            }
            Err(e) => skipped.push(SkippedPath {
                path: p,
                reason: e.to_string(),
            }),
        }
    }
    reg.repos.sort_by_key(|r| r.name.to_lowercase());
    write(&config_dir, &reg)?;
    Ok(AddReport {
        registry: reg,
        added,
        skipped,
    })
}

/// Removes a repository from the list. Files on disk are never touched.
pub fn remove_repo(config_dir: String, path: String) -> CoreResult<Registry> {
    let _g = LOCK.lock().unwrap();
    let mut reg = read(&config_dir)?;
    reg.repos.retain(|r| !same_path(&r.path, &path));
    write(&config_dir, &reg)?;
    Ok(reg)
}

/// Replaces the stored entry with the same path (name and overrides).
pub fn update_repo(config_dir: String, entry: RepoEntry) -> CoreResult<Registry> {
    let _g = LOCK.lock().unwrap();
    let mut reg = read(&config_dir)?;
    let slot = reg
        .repos
        .iter_mut()
        .find(|r| same_path(&r.path, &entry.path))
        .ok_or_else(|| CoreError::InvalidInput {
            message: format!("{} is not in the list", entry.path),
        })?;
    let name = entry.name.trim();
    *slot = RepoEntry {
        name: if name.is_empty() {
            slot.name.clone()
        } else {
            name.to_string()
        },
        fetch_schedule: entry.fetch_schedule.clamped(),
        last_auto_fetch: slot.last_auto_fetch,
        ..entry
    };
    write(&config_dir, &reg)?;
    Ok(reg)
}

pub fn update_settings(config_dir: String, settings: AppSettings) -> CoreResult<Registry> {
    let _g = LOCK.lock().unwrap();
    let mut reg = read(&config_dir)?;
    reg.settings = AppSettings {
        scan_depth: settings.scan_depth.clamp(1, 8),
        ..settings
    };
    write(&config_dir, &reg)?;
    Ok(reg)
}

/// Paths of the repositories whose automatic fetch is due at `now_seconds`
/// (Unix time). A repository that was never fetched automatically is due.
pub fn due_for_fetch(config_dir: String, now_seconds: i64) -> CoreResult<Vec<String>> {
    let _g = LOCK.lock().unwrap();
    let reg = read(&config_dir)?;
    Ok(reg
        .repos
        .iter()
        .filter(|r| r.fetch_schedule.enabled)
        .filter(|r| match r.last_auto_fetch {
            None => true,
            // A clock that jumped backwards counts as due.
            Some(last) => {
                now_seconds < last || now_seconds - last >= r.fetch_schedule.interval_seconds()
            }
        })
        .map(|r| r.path.clone())
        .collect())
}

/// Records an automatic fetch of `path` at `at_seconds` (Unix time).
pub fn mark_auto_fetched(config_dir: String, path: String, at_seconds: i64) -> CoreResult<()> {
    let _g = LOCK.lock().unwrap();
    let mut reg = read(&config_dir)?;
    if let Some(r) = reg.repos.iter_mut().find(|r| same_path(&r.path, &path)) {
        r.last_auto_fetch = Some(at_seconds);
        write(&config_dir, &reg)?;
    }
    Ok(())
}

fn same_path(a: &str, b: &str) -> bool {
    let norm = |s: &str| {
        let s = s.trim_end_matches(['/', '\\']).replace('\\', "/");
        if cfg!(windows) || cfg!(target_os = "macos") {
            s.to_lowercase()
        } else {
            s
        }
    };
    norm(a) == norm(b)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::util::testutil::TestRepo;

    fn cfg() -> (tempfile::TempDir, String) {
        let d = tempfile::tempdir().unwrap();
        let s = d.path().join("config").to_string_lossy().into_owned();
        (d, s)
    }

    #[test]
    fn first_run_has_defaults() {
        let (_d, c) = cfg();
        let reg = load_registry(c).unwrap();
        assert!(reg.repos.is_empty());
        assert_eq!(reg.settings, AppSettings::default());
    }

    #[test]
    fn add_skips_duplicates_and_non_repos() {
        let (_d, c) = cfg();
        let a = TestRepo::new("main");
        let plain = tempfile::tempdir().unwrap();
        let report = add_repos(
            c.clone(),
            vec![
                a.path(),
                format!("{}/", a.path()),
                plain.path().to_string_lossy().into(),
            ],
        )
        .unwrap();
        assert_eq!(report.added.len(), 1);
        assert_eq!(report.skipped.len(), 2);
        let reloaded = load_registry(c).unwrap();
        assert_eq!(reloaded.repos.len(), 1);
        assert!(!reloaded.repos[0].fetch_schedule.enabled, "off by default");
    }

    #[test]
    fn update_and_remove() {
        let (_d, c) = cfg();
        let a = TestRepo::new("main");
        let reg = add_repos(c.clone(), vec![a.path()]).unwrap().registry;
        let mut entry = reg.repos[0].clone();
        entry.name = "Renamed".into();
        entry.pull_strategy = Some(PullStrategy::Rebase);
        let reg = update_repo(c.clone(), entry).unwrap();
        assert_eq!(reg.repos[0].name, "Renamed");
        assert_eq!(reg.repos[0].pull_strategy, Some(PullStrategy::Rebase));
        let reg = remove_repo(c.clone(), a.path()).unwrap();
        assert!(reg.repos.is_empty());
        assert!(a.dir.path().exists(), "files on disk stay");
    }

    #[test]
    fn settings_persist_and_clamp() {
        let (_d, c) = cfg();
        let s = AppSettings {
            push_after_commit: true,
            scan_depth: 99,
            ..Default::default()
        };
        update_settings(c.clone(), s).unwrap();
        let reg = load_registry(c).unwrap();
        assert!(reg.settings.push_after_commit);
        assert_eq!(reg.settings.scan_depth, 8);
    }

    #[test]
    fn older_files_missing_fields_still_load() {
        let (_d, c) = cfg();
        std::fs::create_dir_all(&c).unwrap();
        std::fs::write(
            Path::new(&c).join(FILE_NAME),
            r#"{"repos":[{"path":"/x","name":"x"}]}"#,
        )
        .unwrap();
        let reg = load_registry(c).unwrap();
        assert_eq!(reg.settings, AppSettings::default());
        assert_eq!(reg.repos[0].fetch_schedule, FetchSchedule::off());
    }

    #[test]
    fn old_auto_fetch_flag_is_ignored() {
        let (_d, c) = cfg();
        std::fs::create_dir_all(&c).unwrap();
        std::fs::write(
            Path::new(&c).join(FILE_NAME),
            r#"{"settings":{"auto_fetch_minutes":5},"repos":[{"path":"/x","name":"x","auto_fetch":true}]}"#,
        )
        .unwrap();
        let reg = load_registry(c).unwrap();
        assert!(!reg.repos[0].fetch_schedule.enabled);
    }

    #[test]
    fn schedule_decides_what_is_due() {
        let (_d, c) = cfg();
        let a = TestRepo::new("main");
        let b = TestRepo::new("main");
        let reg = add_repos(c.clone(), vec![a.path(), b.path()])
            .unwrap()
            .registry;
        assert!(
            due_for_fetch(c.clone(), 1_000).unwrap().is_empty(),
            "all off"
        );

        let mut e = reg
            .repos
            .iter()
            .find(|r| r.path == a.path())
            .unwrap()
            .clone();
        e.fetch_schedule = FetchSchedule {
            enabled: true,
            every: 0, // clamped to 1
            unit: FetchUnit::Hours,
        };
        e.last_auto_fetch = Some(42); // ignored: the core owns this field
        let reg = update_repo(c.clone(), e).unwrap();
        let saved = reg.repos.iter().find(|r| r.path == a.path()).unwrap();
        assert_eq!(saved.fetch_schedule.every, 1);
        assert_eq!(saved.last_auto_fetch, None);

        assert_eq!(due_for_fetch(c.clone(), 1_000).unwrap(), vec![a.path()]);
        mark_auto_fetched(c.clone(), a.path(), 1_000).unwrap();
        assert!(due_for_fetch(c.clone(), 1_000 + 3_599).unwrap().is_empty());
        assert_eq!(
            due_for_fetch(c.clone(), 1_000 + 3_600).unwrap(),
            vec![a.path()]
        );
        assert_eq!(due_for_fetch(c.clone(), 10).unwrap(), vec![a.path()]);

        // Editing other settings keeps the last fetch time.
        let mut e = load_registry(c.clone())
            .unwrap()
            .repos
            .into_iter()
            .find(|r| r.path == a.path())
            .unwrap();
        e.name = "A".into();
        e.last_auto_fetch = None;
        update_repo(c.clone(), e).unwrap();
        assert!(due_for_fetch(c.clone(), 1_100).unwrap().is_empty());
    }

    #[test]
    fn interval_units() {
        let s = |every, unit| FetchSchedule {
            enabled: true,
            every,
            unit,
        };
        assert_eq!(s(5, FetchUnit::Minutes).interval_seconds(), 300);
        assert_eq!(s(2, FetchUnit::Hours).interval_seconds(), 7_200);
        assert_eq!(s(3, FetchUnit::Days).interval_seconds(), 259_200);
    }
}
