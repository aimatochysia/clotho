//! GitHub sign-in (OAuth device flow), the REST calls the app shows, and
//! cloning with progress.
//!
//! Tokens never touch disk here: the Dart side keeps them in the OS secure
//! store and passes them in for each call.
use std::path::Path;
use std::time::{Duration, Instant};

use serde::de::DeserializeOwned;
use serde::Deserialize;

use crate::api::remote::{callbacks, AuthOptions};
use crate::error::{CoreError, CoreResult};
use crate::frb_generated::StreamSink;
use crate::util::open_repo;

const API: &str = "https://api.github.com";
const WEB: &str = "https://github.com";

/// Base URLs, so tests can point the client at a local server.
#[derive(Clone)]
struct Endpoints {
    api: String,
    web: String,
}

impl Endpoints {
    fn github() -> Self {
        Endpoints {
            api: API.into(),
            web: WEB.into(),
        }
    }
}

fn agent() -> ureq::Agent {
    ureq::Agent::config_builder()
        .http_status_as_error(false)
        .timeout_global(Some(Duration::from_secs(30)))
        .user_agent(concat!("Clotho/", env!("CARGO_PKG_VERSION")))
        .build()
        .into()
}

fn net_err(err: ureq::Error) -> CoreError {
    CoreError::Network {
        message: err.to_string(),
    }
}

#[derive(Deserialize)]
struct ApiMessage {
    message: Option<String>,
}

/// Maps a non-2xx response to an error a person can act on.
fn status_err(resp: &mut ureq::http::Response<ureq::Body>) -> CoreError {
    let status = resp.status().as_u16();
    let rate_left = resp
        .headers()
        .get("x-ratelimit-remaining")
        .and_then(|v| v.to_str().ok())
        .map(str::to_string);
    let message = resp
        .body_mut()
        .read_json::<ApiMessage>()
        .ok()
        .and_then(|m| m.message)
        .unwrap_or_else(|| "request failed".into());
    match status {
        401 => CoreError::Auth {
            message: "GitHub did not accept the token; sign in again".into(),
        },
        403 | 429 if rate_left.as_deref() == Some("0") => CoreError::GitHub {
            status,
            message: "rate limit reached; try again later or sign in".into(),
        },
        _ => CoreError::GitHub { status, message },
    }
}

/// Performs an authenticated GET against the REST API and decodes the body.
fn api_get<T: DeserializeOwned>(
    ep: &Endpoints,
    token: Option<&str>,
    path_and_query: &str,
) -> CoreResult<(T, Option<String>)> {
    let mut req = agent()
        .get(format!("{}{}", ep.api, path_and_query))
        .header("Accept", "application/vnd.github+json")
        .header("X-GitHub-Api-Version", "2022-11-28");
    if let Some(t) = token.filter(|t| !t.is_empty()) {
        req = req.header("Authorization", format!("Bearer {t}"));
    }
    let mut resp = req.call().map_err(net_err)?;
    if !resp.status().is_success() {
        return Err(status_err(&mut resp));
    }
    let scopes = resp
        .headers()
        .get("x-oauth-scopes")
        .and_then(|v| v.to_str().ok())
        .map(str::to_string);
    let body = resp
        .body_mut()
        .with_config()
        .limit(32 * 1024 * 1024)
        .read_json::<T>()
        .map_err(|e| CoreError::GitHub {
            status: 200,
            message: format!("unexpected response: {e}"),
        })?;
    Ok((body, scopes))
}

fn check_name(part: &str) -> CoreResult<&str> {
    let ok = !part.is_empty()
        && part != "."
        && part != ".."
        && part
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '-' | '_' | '.'));
    if ok {
        Ok(part)
    } else {
        Err(CoreError::InvalidInput {
            message: format!("not a valid GitHub owner or repository name: {part}"),
        })
    }
}

// ---------------------------------------------------------------------------
// Device flow
// ---------------------------------------------------------------------------

/// What the user has to enter on GitHub to approve this device.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
pub struct DeviceCode {
    pub device_code: String,
    pub user_code: String,
    pub verification_uri: String,
    /// Seconds until the code expires.
    pub expires_in: u32,
    /// Seconds to wait between polls.
    pub interval: u32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DevicePoll {
    /// The user has not approved yet; poll again after the interval.
    Pending,
    /// Polling too fast; wait `interval` seconds from now on.
    SlowDown {
        interval: u32,
    },
    Authorized {
        token: String,
        scopes: String,
    },
    Expired,
    Denied,
}

#[derive(Deserialize)]
struct TokenResponse {
    access_token: Option<String>,
    scope: Option<String>,
    error: Option<String>,
    error_description: Option<String>,
    interval: Option<u32>,
}

fn post_form<T: DeserializeOwned>(url: &str, form: &[(&str, &str)]) -> CoreResult<T> {
    let mut resp = agent()
        .post(url)
        .header("Accept", "application/json")
        .send_form(form.iter().copied())
        .map_err(net_err)?;
    if !resp.status().is_success() {
        return Err(status_err(&mut resp));
    }
    resp.body_mut()
        .read_json::<T>()
        .map_err(|e| CoreError::GitHub {
            status: 200,
            message: format!("unexpected response: {e}"),
        })
}

fn start_device_flow_at(ep: &Endpoints, client_id: &str, scopes: &str) -> CoreResult<DeviceCode> {
    if client_id.trim().is_empty() {
        return Err(CoreError::InvalidInput {
            message: "this build has no GitHub client id; use a personal access token".into(),
        });
    }
    #[derive(Deserialize)]
    struct Raw {
        #[serde(flatten)]
        code: Option<DeviceCode>,
        error: Option<String>,
        error_description: Option<String>,
    }
    let raw: Raw = post_form(
        &format!("{}/login/device/code", ep.web),
        &[("client_id", client_id), ("scope", scopes)],
    )?;
    match raw.code {
        Some(code) => Ok(code),
        None => Err(CoreError::GitHub {
            status: 400,
            message: raw
                .error_description
                .or(raw.error)
                .unwrap_or_else(|| "could not start sign-in".into()),
        }),
    }
}

fn poll_device_flow_at(
    ep: &Endpoints,
    client_id: &str,
    device_code: &str,
) -> CoreResult<DevicePoll> {
    let r: TokenResponse = post_form(
        &format!("{}/login/oauth/access_token", ep.web),
        &[
            ("client_id", client_id),
            ("device_code", device_code),
            ("grant_type", "urn:ietf:params:oauth:grant-type:device_code"),
        ],
    )?;
    if let Some(token) = r.access_token {
        return Ok(DevicePoll::Authorized {
            token,
            scopes: r.scope.unwrap_or_default(),
        });
    }
    match r.error.as_deref() {
        Some("authorization_pending") => Ok(DevicePoll::Pending),
        Some("slow_down") => Ok(DevicePoll::SlowDown {
            interval: r.interval.unwrap_or(10),
        }),
        Some("expired_token") => Ok(DevicePoll::Expired),
        Some("access_denied") => Ok(DevicePoll::Denied),
        _ => Err(CoreError::GitHub {
            status: 400,
            message: r
                .error_description
                .or(r.error)
                .unwrap_or_else(|| "sign-in failed".into()),
        }),
    }
}

/// Starts GitHub's device flow. Show `user_code` and open `verification_uri`.
pub fn github_start_device_flow(client_id: String, scopes: String) -> CoreResult<DeviceCode> {
    start_device_flow_at(&Endpoints::github(), &client_id, &scopes)
}

/// Asks GitHub once whether the user approved the device code.
pub fn github_poll_device_flow(client_id: String, device_code: String) -> CoreResult<DevicePoll> {
    poll_device_flow_at(&Endpoints::github(), &client_id, &device_code)
}

// ---------------------------------------------------------------------------
// REST
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GitHubUser {
    pub login: String,
    pub name: Option<String>,
    pub avatar_url: String,
    pub html_url: String,
    /// Scopes the token carries (empty for fine-grained tokens).
    pub scopes: Vec<String>,
}

/// Checks a token and returns who it belongs to.
pub fn github_get_user(token: String) -> CoreResult<GitHubUser> {
    get_user_at(&Endpoints::github(), &token)
}

fn get_user_at(ep: &Endpoints, token: &str) -> CoreResult<GitHubUser> {
    #[derive(Deserialize)]
    struct Raw {
        login: String,
        name: Option<String>,
        avatar_url: String,
        html_url: String,
    }
    let (u, scopes): (Raw, _) = api_get(ep, Some(token), "/user")?;
    Ok(GitHubUser {
        login: u.login,
        name: u.name,
        avatar_url: u.avatar_url,
        html_url: u.html_url,
        scopes: scopes
            .unwrap_or_default()
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect(),
    })
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GitHubRepo {
    pub full_name: String,
    pub owner: String,
    pub name: String,
    pub description: Option<String>,
    pub private: bool,
    pub fork: bool,
    pub archived: bool,
    pub clone_url: String,
    pub ssh_url: String,
    pub html_url: String,
    pub default_branch: String,
    pub language: Option<String>,
    pub stars: u32,
    /// ISO 8601 time of the last push.
    pub pushed_at: Option<String>,
}

#[derive(Deserialize)]
struct RawOwner {
    login: String,
}

#[derive(Deserialize)]
struct RawRepo {
    full_name: String,
    name: String,
    owner: RawOwner,
    description: Option<String>,
    private: bool,
    fork: bool,
    #[serde(default)]
    archived: bool,
    clone_url: String,
    ssh_url: String,
    html_url: String,
    #[serde(default)]
    default_branch: String,
    language: Option<String>,
    #[serde(default)]
    stargazers_count: u32,
    pushed_at: Option<String>,
}

impl From<RawRepo> for GitHubRepo {
    fn from(r: RawRepo) -> Self {
        GitHubRepo {
            full_name: r.full_name,
            owner: r.owner.login,
            name: r.name,
            description: r.description,
            private: r.private,
            fork: r.fork,
            archived: r.archived,
            clone_url: r.clone_url,
            ssh_url: r.ssh_url,
            html_url: r.html_url,
            default_branch: r.default_branch,
            language: r.language,
            stars: r.stargazers_count,
            pushed_at: r.pushed_at,
        }
    }
}

const MAX_REPO_PAGES: u32 = 10;

/// Every repository the signed-in user can access (up to 1000), most recently
/// pushed first.
pub fn github_list_repos(token: String) -> CoreResult<Vec<GitHubRepo>> {
    list_repos_at(&Endpoints::github(), &token)
}

fn list_repos_at(ep: &Endpoints, token: &str) -> CoreResult<Vec<GitHubRepo>> {
    let mut out = vec![];
    for page in 1..=MAX_REPO_PAGES {
        let q = format!(
            "/user/repos?per_page=100&page={page}&sort=pushed\
             &affiliation=owner,collaborator,organization_member"
        );
        let (batch, _): (Vec<RawRepo>, _) = api_get(ep, Some(token), &q)?;
        let n = batch.len();
        out.extend(batch.into_iter().map(GitHubRepo::from));
        if n < 100 {
            break;
        }
    }
    Ok(out)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GitHubPull {
    pub number: u32,
    pub title: String,
    pub author: String,
    pub state: String,
    pub draft: bool,
    pub html_url: String,
    pub head_ref: String,
    pub base_ref: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GitHubIssue {
    pub number: u32,
    pub title: String,
    pub author: String,
    pub state: String,
    pub html_url: String,
    pub comments: u32,
    pub labels: Vec<String>,
    pub updated_at: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WorkflowRun {
    pub id: u64,
    pub name: String,
    pub title: String,
    pub branch: String,
    pub event: String,
    /// queued, in_progress or completed.
    pub status: String,
    /// success, failure, cancelled, … once completed.
    pub conclusion: Option<String>,
    pub run_number: u32,
    pub html_url: String,
    pub created_at: String,
}

#[derive(Deserialize)]
struct RawUser {
    login: String,
}

fn state_param(state: &str) -> &str {
    match state {
        "closed" | "all" => state,
        _ => "open",
    }
}

/// Pull requests of `owner/repo` (state: open, closed or all).
pub fn github_list_pulls(
    token: Option<String>,
    owner: String,
    repo: String,
    state: String,
) -> CoreResult<Vec<GitHubPull>> {
    list_pulls_at(
        &Endpoints::github(),
        token.as_deref(),
        &owner,
        &repo,
        &state,
    )
}

fn list_pulls_at(
    ep: &Endpoints,
    token: Option<&str>,
    owner: &str,
    repo: &str,
    state: &str,
) -> CoreResult<Vec<GitHubPull>> {
    #[derive(Deserialize)]
    struct Ref {
        #[serde(rename = "ref")]
        name: String,
    }
    #[derive(Deserialize)]
    struct Raw {
        number: u32,
        title: String,
        user: Option<RawUser>,
        state: String,
        #[serde(default)]
        draft: bool,
        html_url: String,
        head: Ref,
        base: Ref,
        updated_at: String,
    }
    let q = format!(
        "/repos/{}/{}/pulls?state={}&per_page=50&sort=updated&direction=desc",
        check_name(owner)?,
        check_name(repo)?,
        state_param(state)
    );
    let (raw, _): (Vec<Raw>, _) = api_get(ep, token, &q)?;
    Ok(raw
        .into_iter()
        .map(|p| GitHubPull {
            number: p.number,
            title: p.title,
            author: p.user.map(|u| u.login).unwrap_or_default(),
            state: p.state,
            draft: p.draft,
            html_url: p.html_url,
            head_ref: p.head.name,
            base_ref: p.base.name,
            updated_at: p.updated_at,
        })
        .collect())
}

/// Issues of `owner/repo`, without pull requests (state: open, closed or all).
pub fn github_list_issues(
    token: Option<String>,
    owner: String,
    repo: String,
    state: String,
) -> CoreResult<Vec<GitHubIssue>> {
    list_issues_at(
        &Endpoints::github(),
        token.as_deref(),
        &owner,
        &repo,
        &state,
    )
}

fn list_issues_at(
    ep: &Endpoints,
    token: Option<&str>,
    owner: &str,
    repo: &str,
    state: &str,
) -> CoreResult<Vec<GitHubIssue>> {
    #[derive(Deserialize)]
    struct Label {
        name: String,
    }
    #[derive(Deserialize)]
    struct Raw {
        number: u32,
        title: String,
        user: Option<RawUser>,
        state: String,
        html_url: String,
        #[serde(default)]
        comments: u32,
        #[serde(default)]
        labels: Vec<Label>,
        updated_at: String,
        pull_request: Option<serde_json::Value>,
    }
    let q = format!(
        "/repos/{}/{}/issues?state={}&per_page=50&sort=updated&direction=desc",
        check_name(owner)?,
        check_name(repo)?,
        state_param(state)
    );
    let (raw, _): (Vec<Raw>, _) = api_get(ep, token, &q)?;
    Ok(raw
        .into_iter()
        .filter(|i| i.pull_request.is_none())
        .map(|i| GitHubIssue {
            number: i.number,
            title: i.title,
            author: i.user.map(|u| u.login).unwrap_or_default(),
            state: i.state,
            html_url: i.html_url,
            comments: i.comments,
            labels: i.labels.into_iter().map(|l| l.name).collect(),
            updated_at: i.updated_at,
        })
        .collect())
}

/// The latest GitHub Actions runs of `owner/repo`.
pub fn github_list_runs(
    token: Option<String>,
    owner: String,
    repo: String,
) -> CoreResult<Vec<WorkflowRun>> {
    list_runs_at(&Endpoints::github(), token.as_deref(), &owner, &repo)
}

fn list_runs_at(
    ep: &Endpoints,
    token: Option<&str>,
    owner: &str,
    repo: &str,
) -> CoreResult<Vec<WorkflowRun>> {
    #[derive(Deserialize)]
    struct Raw {
        id: u64,
        name: Option<String>,
        display_title: Option<String>,
        head_branch: Option<String>,
        event: String,
        status: Option<String>,
        conclusion: Option<String>,
        run_number: u32,
        html_url: String,
        created_at: String,
    }
    #[derive(Deserialize)]
    struct Page {
        workflow_runs: Vec<Raw>,
    }
    let q = format!(
        "/repos/{}/{}/actions/runs?per_page=30",
        check_name(owner)?,
        check_name(repo)?
    );
    let (page, _): (Page, _) = api_get(ep, token, &q)?;
    Ok(page
        .workflow_runs
        .into_iter()
        .map(|r| WorkflowRun {
            id: r.id,
            name: r.name.unwrap_or_default(),
            title: r.display_title.unwrap_or_default(),
            branch: r.head_branch.unwrap_or_default(),
            event: r.event,
            status: r.status.unwrap_or_default(),
            conclusion: r.conclusion,
            run_number: r.run_number,
            html_url: r.html_url,
            created_at: r.created_at,
        })
        .collect())
}

// ---------------------------------------------------------------------------
// Remotes and cloning
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GitHubRemote {
    pub remote: String,
    pub owner: String,
    pub repo: String,
}

/// Parses `https://github.com/o/r(.git)`, `git@github.com:o/r(.git)` and
/// `ssh://git@github.com/o/r(.git)` into owner and repository.
pub(crate) fn parse_github_url(url: &str) -> Option<(String, String)> {
    let url = url.trim();
    let rest = if let Some(r) = url.strip_prefix("git@github.com:") {
        r.to_string()
    } else {
        let u = url::Url::parse(url).ok()?;
        if !matches!(u.scheme(), "https" | "http" | "ssh" | "git") {
            return None;
        }
        if !u.host_str()?.eq_ignore_ascii_case("github.com") {
            return None;
        }
        u.path().trim_start_matches('/').to_string()
    };
    let rest = rest.trim_end_matches('/');
    let rest = rest.strip_suffix(".git").unwrap_or(rest);
    let mut parts = rest.split('/');
    let owner = parts.next()?;
    let repo = parts.next()?;
    if parts.next().is_some() || check_name(owner).is_err() || check_name(repo).is_err() {
        return None;
    }
    Some((owner.to_string(), repo.to_string()))
}

/// The GitHub repository behind `origin` (or the first GitHub remote), if any.
pub fn github_remote_of(path: String) -> CoreResult<Option<GitHubRemote>> {
    let repo = open_repo(&path)?;
    let names: Vec<String> = repo
        .remotes()?
        .iter()
        .flatten()
        .map(str::to_string)
        .collect();
    let ordered = names
        .iter()
        .filter(|n| *n == "origin")
        .chain(names.iter().filter(|n| *n != "origin"));
    for name in ordered {
        let remote = repo.find_remote(name)?;
        if let Some((owner, r)) = remote.url().and_then(parse_github_url) {
            return Ok(Some(GitHubRemote {
                remote: name.clone(),
                owner,
                repo: r,
            }));
        }
    }
    Ok(None)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CloneProgress {
    Receiving {
        received_objects: u32,
        total_objects: u32,
        received_bytes: u64,
    },
    Resolving {
        indexed_deltas: u32,
        total_deltas: u32,
    },
    CheckingOut {
        done: u32,
        total: u32,
    },
    /// The clone finished at `path`.
    Done {
        path: String,
    },
}

/// Clones `url` into `dest` (which must not exist or be empty), reporting
/// progress on `sink`. The stream ends with [`CloneProgress::Done`].
pub fn clone_repo(
    url: String,
    dest: String,
    auth: AuthOptions,
    sink: StreamSink<CloneProgress>,
) -> CoreResult<()> {
    let path = clone_with(&url, &dest, &auth, |p| {
        let _ = sink.add(p);
    })?;
    let _ = sink.add(CloneProgress::Done { path });
    Ok(())
}

fn clone_with(
    url: &str,
    dest: &str,
    auth: &AuthOptions,
    mut report: impl FnMut(CloneProgress),
) -> CoreResult<String> {
    let target = Path::new(dest);
    if target.exists() {
        let has_entries = std::fs::read_dir(target)?.next().is_some();
        if has_entries || !target.is_dir() {
            return Err(CoreError::InvalidInput {
                message: format!("{dest} already exists and is not empty"),
            });
        }
    }
    if url.trim().is_empty() {
        return Err(CoreError::InvalidInput {
            message: "enter a repository URL".into(),
        });
    }
    let config = git2::Config::open_default()?;
    let report = std::cell::RefCell::new(&mut report);
    let mut last = Instant::now() - Duration::from_secs(1);
    let mut cb = callbacks(auth, config);
    cb.transfer_progress(|s| {
        let throttle = Instant::now().duration_since(last) >= Duration::from_millis(100);
        let finished =
            s.received_objects() == s.total_objects() && s.indexed_deltas() == s.total_deltas();
        if throttle || finished {
            last = Instant::now();
            let p = if s.received_objects() < s.total_objects() {
                CloneProgress::Receiving {
                    received_objects: s.received_objects() as u32,
                    total_objects: s.total_objects() as u32,
                    received_bytes: s.received_bytes() as u64,
                }
            } else {
                CloneProgress::Resolving {
                    indexed_deltas: s.indexed_deltas() as u32,
                    total_deltas: s.total_deltas() as u32,
                }
            };
            (report.borrow_mut())(p);
        }
        true
    });
    let mut fo = git2::FetchOptions::new();
    fo.remote_callbacks(cb);
    let mut co = git2::build::CheckoutBuilder::new();
    let mut last_co = 0usize;
    co.progress(|_, done, total| {
        if done == total || done >= last_co + 50 {
            last_co = done;
            (report.borrow_mut())(CloneProgress::CheckingOut {
                done: done as u32,
                total: total as u32,
            });
        }
    });
    let result = git2::build::RepoBuilder::new()
        .fetch_options(fo)
        .with_checkout(co)
        .clone(url, target);
    match result {
        Ok(_) => Ok(crate::util::path_to_string(target)),
        Err(e) => {
            // Leave nothing half-cloned behind.
            if target.exists() {
                let _ = std::fs::remove_dir_all(target);
            }
            Err(e.into())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::util::testutil::*;
    use std::io::{BufRead, BufReader, Read, Write};
    use std::net::TcpListener;
    use std::sync::{Arc, Mutex};

    /// A one-thread HTTP server that answers each request with the next
    /// canned (status, extra headers, body) and records the request lines.
    struct Mock {
        base: String,
        seen: Arc<Mutex<Vec<String>>>,
    }

    fn mock(responses: Vec<(u16, &'static str, &'static str)>) -> Mock {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let base = format!("http://{}", listener.local_addr().unwrap());
        let seen = Arc::new(Mutex::new(vec![]));
        let log = seen.clone();
        std::thread::spawn(move || {
            for (status, headers, body) in responses {
                let (mut stream, _) = listener.accept().unwrap();
                let mut reader = BufReader::new(stream.try_clone().unwrap());
                let mut line = String::new();
                reader.read_line(&mut line).unwrap();
                let mut len = 0usize;
                let mut auth = String::new();
                loop {
                    let mut h = String::new();
                    reader.read_line(&mut h).unwrap();
                    if h == "\r\n" || h.is_empty() {
                        break;
                    }
                    let lower = h.to_lowercase();
                    if let Some(v) = lower.strip_prefix("content-length:") {
                        len = v.trim().parse().unwrap();
                    }
                    if lower.starts_with("authorization:") {
                        auth = h.trim().to_string();
                    }
                }
                let mut body_in = vec![0; len];
                reader.read_exact(&mut body_in).unwrap();
                log.lock().unwrap().push(format!(
                    "{} {} {}",
                    line.trim(),
                    auth,
                    String::from_utf8_lossy(&body_in)
                ));
                let resp = format!(
                    "HTTP/1.1 {status} X\r\nContent-Type: application/json\r\n{headers}\
                     Content-Length: {}\r\nConnection: close\r\n\r\n{body}",
                    body.len()
                );
                stream.write_all(resp.as_bytes()).unwrap();
            }
        });
        Mock { base, seen }
    }

    fn ep(m: &Mock) -> Endpoints {
        Endpoints {
            api: m.base.clone(),
            web: m.base.clone(),
        }
    }

    #[test]
    fn parses_github_urls() {
        let want = Some(("octo".to_string(), "hello.world".to_string()));
        assert_eq!(
            parse_github_url("https://github.com/octo/hello.world.git"),
            want
        );
        assert_eq!(
            parse_github_url("https://github.com/octo/hello.world"),
            want
        );
        assert_eq!(
            parse_github_url("git@github.com:octo/hello.world.git"),
            want
        );
        assert_eq!(
            parse_github_url("ssh://git@github.com/octo/hello.world"),
            want
        );
        assert_eq!(parse_github_url("https://gitlab.com/octo/x"), None);
        assert_eq!(parse_github_url("https://github.com/octo"), None);
        assert_eq!(
            parse_github_url("https://github.com/octo/x/tree/main"),
            None
        );
    }

    #[test]
    fn remote_of_prefers_origin() {
        let t = TestRepo::new("main");
        let repo = &t.repo;
        repo.remote("backup", "https://example.com/x/y.git")
            .unwrap();
        repo.remote("upstream", "git@github.com:other/y.git")
            .unwrap();
        assert_eq!(github_remote_of(t.path()).unwrap().unwrap().owner, "other");
        repo.remote("origin", "https://github.com/me/y").unwrap();
        let r = github_remote_of(t.path()).unwrap().unwrap();
        assert_eq!((r.remote.as_str(), r.owner.as_str()), ("origin", "me"));
    }

    #[test]
    fn rejects_bad_names() {
        assert!(check_name("..").is_err());
        assert!(check_name("a/b").is_err());
        assert!(check_name("a?b").is_err());
        assert!(check_name("ok-name_1.x").is_ok());
    }

    #[test]
    fn device_flow_round_trip() {
        let m = mock(vec![
            (
                200,
                "",
                r#"{"device_code":"dc","user_code":"ABCD-1234","verification_uri":"https://github.com/login/device","expires_in":900,"interval":5}"#,
            ),
            (200, "", r#"{"error":"authorization_pending"}"#),
            (200, "", r#"{"error":"slow_down","interval":10}"#),
            (
                200,
                "",
                r#"{"access_token":"gho_x","token_type":"bearer","scope":"repo"}"#,
            ),
            (200, "", r#"{"error":"access_denied"}"#),
        ]);
        let e = ep(&m);
        let code = start_device_flow_at(&e, "cid", "repo").unwrap();
        assert_eq!(code.user_code, "ABCD-1234");
        assert_eq!(
            poll_device_flow_at(&e, "cid", "dc").unwrap(),
            DevicePoll::Pending
        );
        assert_eq!(
            poll_device_flow_at(&e, "cid", "dc").unwrap(),
            DevicePoll::SlowDown { interval: 10 }
        );
        assert_eq!(
            poll_device_flow_at(&e, "cid", "dc").unwrap(),
            DevicePoll::Authorized {
                token: "gho_x".into(),
                scopes: "repo".into()
            }
        );
        assert_eq!(
            poll_device_flow_at(&e, "cid", "dc").unwrap(),
            DevicePoll::Denied
        );
        let seen = m.seen.lock().unwrap();
        assert!(seen[0].starts_with("POST /login/device/code"));
        assert!(seen[0].contains("client_id=cid"));
        assert!(seen[1].contains("grant_type=urn%3Aietf"));
    }

    #[test]
    fn device_flow_needs_client_id() {
        let e = Endpoints::github();
        assert!(matches!(
            start_device_flow_at(&e, " ", "repo"),
            Err(CoreError::InvalidInput { .. })
        ));
    }

    #[test]
    fn user_and_scopes() {
        let m = mock(vec![(
            200,
            "X-OAuth-Scopes: repo, read:user, workflow\r\n",
            r#"{"login":"octo","name":null,"avatar_url":"a","html_url":"h"}"#,
        )]);
        let u = get_user_at(&ep(&m), "tok").unwrap();
        assert_eq!(u.login, "octo");
        assert_eq!(u.scopes, vec!["repo", "read:user", "workflow"]);
        assert!(m.seen.lock().unwrap()[0].contains("Bearer tok"));
    }

    #[test]
    fn bad_token_is_auth_error() {
        let m = mock(vec![(401, "", r#"{"message":"Bad credentials"}"#)]);
        assert!(matches!(
            get_user_at(&ep(&m), "tok"),
            Err(CoreError::Auth { .. })
        ));
    }

    #[test]
    fn rate_limit_message() {
        let m = mock(vec![(
            403,
            "X-RateLimit-Remaining: 0\r\n",
            r#"{"message":"API rate limit exceeded"}"#,
        )]);
        match list_runs_at(&ep(&m), None, "o", "r") {
            Err(CoreError::GitHub { status, message }) => {
                assert_eq!(status, 403);
                assert!(message.contains("rate limit"));
            }
            other => panic!("unexpected {other:?}"),
        }
    }

    #[test]
    fn issues_skip_pull_requests() {
        let m = mock(vec![(
            200,
            "",
            r#"[{"number":1,"title":"bug","user":{"login":"a"},"state":"open","html_url":"u","comments":2,"labels":[{"name":"bug"}],"updated_at":"t"},
               {"number":2,"title":"pr","user":{"login":"b"},"state":"open","html_url":"u","comments":0,"labels":[],"updated_at":"t","pull_request":{}}]"#,
        )]);
        let issues = list_issues_at(&ep(&m), None, "o", "r", "open").unwrap();
        assert_eq!(issues.len(), 1);
        assert_eq!(issues[0].labels, vec!["bug"]);
        assert!(m.seen.lock().unwrap()[0].starts_with("GET /repos/o/r/issues?state=open"));
    }

    #[test]
    fn pulls_and_runs_decode() {
        let m = mock(vec![
            (
                200,
                "",
                r#"[{"number":7,"title":"feat","user":{"login":"a"},"state":"open","draft":true,"html_url":"u","head":{"ref":"f"},"base":{"ref":"main"},"updated_at":"t"}]"#,
            ),
            (
                200,
                "",
                r#"{"total_count":1,"workflow_runs":[{"id":9,"name":"CI","display_title":"feat","head_branch":"f","event":"push","status":"completed","conclusion":"success","run_number":3,"html_url":"u","created_at":"t"}]}"#,
            ),
        ]);
        let e = ep(&m);
        let pulls = list_pulls_at(&e, Some("t"), "o", "r", "bogus").unwrap();
        assert_eq!((pulls[0].number, pulls[0].draft), (7, true));
        assert_eq!(pulls[0].base_ref, "main");
        let runs = list_runs_at(&e, Some("t"), "o", "r").unwrap();
        assert_eq!(runs[0].conclusion.as_deref(), Some("success"));
        // An unknown state falls back to open.
        assert!(m.seen.lock().unwrap()[0].contains("state=open"));
    }

    #[test]
    fn repos_paginate() {
        let full: &'static str = Box::leak(
            format!(
                "[{}]",
                (0..100)
                    .map(|i| format!(
                        r#"{{"full_name":"o/r{i}","name":"r{i}","owner":{{"login":"o"}},"description":null,"private":false,"fork":false,"clone_url":"c","ssh_url":"s","html_url":"h","default_branch":"main","language":null,"stargazers_count":1,"pushed_at":null}}"#
                    ))
                    .collect::<Vec<_>>()
                    .join(",")
            )
            .into_boxed_str(),
        );
        let m = mock(vec![(200, "", full), (200, "", "[]")]);
        let repos = list_repos_at(&ep(&m), "t").unwrap();
        assert_eq!(repos.len(), 100);
        assert_eq!(m.seen.lock().unwrap().len(), 2);
    }

    #[test]
    fn clones_local_repo_with_progress() {
        let pair = RemotePair::new();
        pair.local.commit_file("a.txt", "a", "first");
        push_head(&pair.local);
        let dest = tempfile::tempdir().unwrap();
        let target = dest.path().join("copy");
        let mut events = vec![];
        let path = clone_with(
            &remote_url(pair.remote_dir.path()),
            target.to_str().unwrap(),
            &AuthOptions::default(),
            |p| events.push(p),
        )
        .unwrap();
        assert!(Path::new(&path).join("a.txt").exists());
        assert!(events
            .iter()
            .any(|e| matches!(e, CloneProgress::CheckingOut { .. })));
    }

    #[test]
    fn clone_refuses_non_empty_dest() {
        let dest = tempfile::tempdir().unwrap();
        std::fs::write(dest.path().join("x"), "x").unwrap();
        let r = clone_with(
            "https://github.com/o/r",
            dest.path().to_str().unwrap(),
            &AuthOptions::default(),
            |_| {},
        );
        assert!(matches!(r, Err(CoreError::InvalidInput { .. })));
        assert!(dest.path().join("x").exists());
    }
}
