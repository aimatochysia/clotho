//! In-app updates: find the newest Clotho release on GitHub, download the
//! package for this platform, and refuse it unless both the minisign
//! signature over `SHA256SUMS.txt` and the file's SHA-256 match.
use std::fs::File;
use std::io::{Read, Write};
use std::path::Path;
use std::time::{Duration, Instant};

use serde::Deserialize;
use sha2::{Digest, Sha256};

use crate::error::{CoreError, CoreResult};
use crate::frb_generated::StreamSink;

/// The release-signing public key (also in `packaging/clotho-update.pub`).
const UPDATE_PUBLIC_KEY: &str = "untrusted comment: minisign public key 64E4889CCC838D81
RWSBjYPMnIjkZPFetXOBweP5Gc562r1IZL7HSjBJwXtpo56s344T08tr
";

const RELEASES_API: &str = "https://api.github.com/repos/aimatochysia/clotho/releases";
const SUMS_NAME: &str = "SHA256SUMS.txt";
const SIG_NAME: &str = "SHA256SUMS.txt.minisig";

/// How Clotho was installed, which decides the package an update needs.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PackageKind {
    Deb,
    Arch,
    Tarball,
    Apk,
    Dmg,
    WindowsInstaller,
    WindowsZip,
    Unknown,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlatformInfo {
    pub os: String,
    pub arch: String,
    pub package: PackageKind,
}

/// Detects the platform and the way this copy of Clotho was installed.
#[flutter_rust_bridge::frb(sync)]
pub fn current_platform() -> PlatformInfo {
    let os = std::env::consts::OS.to_string();
    let arch = std::env::consts::ARCH.to_string();
    let exe = std::env::current_exe().ok();
    let package = match os.as_str() {
        "android" => PackageKind::Apk,
        "macos" => PackageKind::Dmg,
        "windows" => {
            let installed = exe
                .as_deref()
                .and_then(Path::parent)
                .map(|d| d.join("unins000.exe").exists())
                .unwrap_or(false);
            if installed {
                PackageKind::WindowsInstaller
            } else {
                PackageKind::WindowsZip
            }
        }
        "linux" => linux_package(exe.as_deref()),
        _ => PackageKind::Unknown,
    };
    PlatformInfo { os, arch, package }
}

fn linux_package(exe: Option<&Path>) -> PackageKind {
    let system = exe.is_some_and(|p| p.starts_with("/usr/lib/clotho"));
    if !system {
        return PackageKind::Tarball;
    }
    if Path::new("/var/lib/dpkg/info/clotho.list").exists() {
        return PackageKind::Deb;
    }
    let pacman = std::fs::read_dir("/var/lib/pacman/local")
        .map(|it| {
            it.flatten().any(|e| {
                e.file_name()
                    .to_str()
                    .and_then(|n| n.strip_prefix("clotho-"))
                    .is_some_and(|rest| rest.starts_with(|c: char| c.is_ascii_digit()))
            })
        })
        .unwrap_or(false);
    if pacman {
        PackageKind::Arch
    } else {
        PackageKind::Tarball
    }
}

/// File name of the release asset for `version` on `platform`. Keep in sync
/// with `.github/workflows/release.yml`.
pub fn asset_name_for(version: String, platform: PlatformInfo) -> Option<String> {
    let v = version.trim_start_matches('v');
    let name = match platform.package {
        PackageKind::Deb => format!("clotho-{v}-linux-amd64.deb"),
        PackageKind::Arch => format!("clotho-{v}-linux-x86_64.pkg.tar.zst"),
        PackageKind::Tarball => format!("clotho-{v}-linux-x86_64.tar.gz"),
        PackageKind::Dmg => format!("clotho-{v}-macos.dmg"),
        PackageKind::WindowsInstaller => format!("clotho-{v}-windows-x64-setup.exe"),
        PackageKind::WindowsZip => format!("clotho-{v}-windows-x64.zip"),
        PackageKind::Apk => {
            let abi = match platform.arch.as_str() {
                "aarch64" => "arm64-v8a",
                "arm" => "armeabi-v7a",
                "x86_64" => "x86_64",
                _ => return None,
            };
            format!("clotho-{v}-android-{abi}.apk")
        }
        PackageKind::Unknown => return None,
    };
    Some(name)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReleaseAsset {
    pub name: String,
    pub url: String,
    pub size: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UpdateInfo {
    pub version: String,
    pub tag: String,
    pub name: String,
    /// Release notes (Markdown).
    pub notes: String,
    pub html_url: String,
    pub published_at: Option<String>,
    /// The package for this platform, if the release has one.
    pub asset: Option<ReleaseAsset>,
    pub sums_url: Option<String>,
    pub signature_url: Option<String>,
}

#[derive(Deserialize)]
struct RawAsset {
    name: String,
    browser_download_url: String,
    #[serde(default)]
    size: u64,
}

#[derive(Deserialize)]
struct RawRelease {
    tag_name: String,
    name: Option<String>,
    body: Option<String>,
    html_url: String,
    published_at: Option<String>,
    #[serde(default)]
    draft: bool,
    #[serde(default)]
    prerelease: bool,
    #[serde(default)]
    assets: Vec<RawAsset>,
}

fn agent(timeout: Duration) -> ureq::Agent {
    ureq::Agent::config_builder()
        .http_status_as_error(false)
        .timeout_global(Some(timeout))
        .user_agent(concat!("Clotho/", env!("CARGO_PKG_VERSION")))
        .build()
        .into()
}

fn net_err(e: ureq::Error) -> CoreError {
    CoreError::Network {
        message: e.to_string(),
    }
}

fn parse_version(s: &str) -> CoreResult<semver::Version> {
    semver::Version::parse(s.trim().trim_start_matches('v')).map_err(|e| CoreError::InvalidInput {
        message: format!("not a version number: {s} ({e})"),
    })
}

/// Picks the newest stable release above `current` from a releases listing.
fn newest_update(
    releases: Vec<RawRelease>,
    current: &str,
    platform: &PlatformInfo,
) -> CoreResult<Option<UpdateInfo>> {
    let current = parse_version(current)?;
    let best = releases
        .into_iter()
        .filter(|r| !r.draft && !r.prerelease)
        .filter_map(|r| parse_version(&r.tag_name).ok().map(|v| (v, r)))
        .filter(|(v, _)| v.pre.is_empty() && *v > current)
        .max_by(|a, b| a.0.cmp(&b.0));
    let Some((version, r)) = best else {
        return Ok(None);
    };
    let version = version.to_string();
    let wanted = asset_name_for(version.clone(), platform.clone());
    let find = |name: &str| r.assets.iter().find(|a| a.name == name);
    let asset = wanted.as_deref().and_then(find).map(|a| ReleaseAsset {
        name: a.name.clone(),
        url: a.browser_download_url.clone(),
        size: a.size,
    });
    Ok(Some(UpdateInfo {
        sums_url: find(SUMS_NAME).map(|a| a.browser_download_url.clone()),
        signature_url: find(SIG_NAME).map(|a| a.browser_download_url.clone()),
        version,
        name: r
            .name
            .filter(|n| !n.is_empty())
            .unwrap_or(r.tag_name.clone()),
        tag: r.tag_name,
        notes: r.body.unwrap_or_default(),
        html_url: r.html_url,
        published_at: r.published_at,
        asset,
    }))
}

/// Asks GitHub for a release newer than `current_version`. `None` means
/// Clotho is up to date.
pub fn check_for_update(current_version: String) -> CoreResult<Option<UpdateInfo>> {
    check_at(RELEASES_API, &current_version, &current_platform())
}

fn check_at(url: &str, current: &str, platform: &PlatformInfo) -> CoreResult<Option<UpdateInfo>> {
    let mut resp = agent(Duration::from_secs(20))
        .get(format!("{url}?per_page=20"))
        .header("Accept", "application/vnd.github+json")
        .call()
        .map_err(net_err)?;
    if !resp.status().is_success() {
        return Err(CoreError::GitHub {
            status: resp.status().as_u16(),
            message: "could not read the release list".into(),
        });
    }
    let releases: Vec<RawRelease> = resp.body_mut().read_json().map_err(|e| CoreError::GitHub {
        status: 200,
        message: format!("unexpected release list: {e}"),
    })?;
    newest_update(releases, current, platform)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DownloadProgress {
    Downloading {
        received: u64,
        total: u64,
    },
    Verifying,
    /// The verified file is at `path`.
    Done {
        path: String,
        sha256: String,
    },
}

fn fetch_text(url: &str) -> CoreResult<String> {
    let mut resp = agent(Duration::from_secs(30))
        .get(url)
        .call()
        .map_err(net_err)?;
    if !resp.status().is_success() {
        return Err(CoreError::GitHub {
            status: resp.status().as_u16(),
            message: format!("download failed: {url}"),
        });
    }
    resp.body_mut()
        .with_config()
        .limit(1024 * 1024)
        .read_to_string()
        .map_err(net_err)
}

fn integrity(message: impl Into<String>) -> CoreError {
    CoreError::Integrity {
        message: message.into(),
    }
}

/// Checks the minisign signature of `sums` and returns the expected SHA-256
/// (lowercase hex) of `asset_name`.
fn expected_hash(
    public_key: &str,
    sums: &str,
    signature: &str,
    asset_name: &str,
) -> CoreResult<String> {
    let pk = minisign_verify::PublicKey::decode(public_key)
        .map_err(|e| integrity(format!("bad public key: {e}")))?;
    let sig = minisign_verify::Signature::decode(signature)
        .map_err(|e| integrity(format!("unreadable signature: {e}")))?;
    pk.verify(sums.as_bytes(), &sig, false)
        .map_err(|_| integrity("the checksum list is not signed by the Clotho release key"))?;
    for line in sums.lines() {
        // `sha256sum` format: "<hex>  <name>" (a `*` marks binary mode).
        let Some((hash, name)) = line.split_once(char::is_whitespace) else {
            continue;
        };
        let name = name.trim_start().trim_start_matches('*');
        if name == asset_name {
            let hash = hash.to_ascii_lowercase();
            if hash.len() == 64 && hash.chars().all(|c| c.is_ascii_hexdigit()) {
                return Ok(hash);
            }
        }
    }
    Err(integrity(format!(
        "{asset_name} is not in the checksum list"
    )))
}

fn safe_file_name(name: &str) -> CoreResult<&str> {
    let ok = !name.is_empty()
        && !name.starts_with('.')
        && name
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '-' | '_' | '.'));
    if ok {
        Ok(name)
    } else {
        Err(CoreError::InvalidInput {
            message: format!("unexpected file name: {name}"),
        })
    }
}

/// Streams `url` into `dest`, hashing as it goes. Returns the hex SHA-256.
fn download_to(
    url: &str,
    dest: &Path,
    size_hint: u64,
    mut progress: impl FnMut(u64, u64),
) -> CoreResult<String> {
    let mut resp = agent(Duration::from_secs(60 * 30))
        .get(url)
        .call()
        .map_err(net_err)?;
    if !resp.status().is_success() {
        return Err(CoreError::GitHub {
            status: resp.status().as_u16(),
            message: format!("download failed: {url}"),
        });
    }
    let total = resp
        .headers()
        .get("content-length")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.parse().ok())
        .unwrap_or(size_hint);
    let mut reader = resp
        .body_mut()
        .with_config()
        .limit(2 * 1024 * 1024 * 1024)
        .reader();
    let mut file = File::create(dest)?;
    let mut hasher = Sha256::new();
    let mut buf = vec![0u8; 64 * 1024];
    let mut received = 0u64;
    let mut last = Instant::now();
    loop {
        let n = reader.read(&mut buf).map_err(|e| CoreError::Network {
            message: e.to_string(),
        })?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
        file.write_all(&buf[..n])?;
        received += n as u64;
        if last.elapsed() >= Duration::from_millis(150) {
            last = Instant::now();
            progress(received, total);
        }
    }
    file.sync_all()?;
    progress(received, total);
    Ok(hex(&hasher.finalize()))
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

/// SHA-256 of a file on disk, as lowercase hex.
pub fn sha256_file(path: String) -> CoreResult<String> {
    let mut f = File::open(&path)?;
    let mut hasher = Sha256::new();
    let mut buf = vec![0u8; 64 * 1024];
    loop {
        let n = f.read(&mut buf)?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
    }
    Ok(hex(&hasher.finalize()))
}

/// Downloads the update package into `dest_dir` and verifies it. The file
/// only appears under its real name once the signature and checksum match.
pub fn download_update(
    update: UpdateInfo,
    dest_dir: String,
    sink: StreamSink<DownloadProgress>,
) -> CoreResult<()> {
    let done = download_verified(UPDATE_PUBLIC_KEY, &update, &dest_dir, |p| {
        let _ = sink.add(p);
    })?;
    let _ = sink.add(done);
    Ok(())
}

fn download_verified(
    public_key: &str,
    update: &UpdateInfo,
    dest_dir: &str,
    mut report: impl FnMut(DownloadProgress),
) -> CoreResult<DownloadProgress> {
    let asset = update
        .asset
        .as_ref()
        .ok_or_else(|| CoreError::InvalidInput {
            message: "this release has no package for your system".into(),
        })?;
    let (Some(sums_url), Some(sig_url)) = (&update.sums_url, &update.signature_url) else {
        return Err(integrity("this release has no signed checksum list"));
    };
    let name = safe_file_name(&asset.name)?;
    // Check the signature first, so nothing unsigned is even downloaded.
    let sums = fetch_text(sums_url)?;
    let sig = fetch_text(sig_url)?;
    let expected = expected_hash(public_key, &sums, &sig, name)?;

    std::fs::create_dir_all(dest_dir)?;
    let final_path = Path::new(dest_dir).join(name);
    let part = Path::new(dest_dir).join(format!("{name}.part"));
    let actual = download_to(&asset.url, &part, asset.size, |received, total| {
        report(DownloadProgress::Downloading { received, total })
    });
    let actual = match actual {
        Ok(h) => h,
        Err(e) => {
            let _ = std::fs::remove_file(&part);
            return Err(e);
        }
    };
    report(DownloadProgress::Verifying);
    if actual != expected {
        let _ = std::fs::remove_file(&part);
        return Err(integrity(format!(
            "{name} is corrupted or was tampered with (SHA-256 mismatch)"
        )));
    }
    if final_path.exists() {
        std::fs::remove_file(&final_path)?;
    }
    std::fs::rename(&part, &final_path)?;
    Ok(DownloadProgress::Done {
        path: crate::util::path_to_string(&final_path),
        sha256: actual,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{BufRead, BufReader};
    use std::net::TcpListener;

    fn platform(package: PackageKind, arch: &str) -> PlatformInfo {
        PlatformInfo {
            os: "test".into(),
            arch: arch.into(),
            package,
        }
    }

    #[test]
    fn embedded_key_matches_packaging_file() {
        let file = include_str!("../../../../packaging/clotho-update.pub");
        assert_eq!(file.replace("\r\n", "\n").trim(), UPDATE_PUBLIC_KEY.trim());
        assert!(minisign_verify::PublicKey::decode(UPDATE_PUBLIC_KEY).is_ok());
    }

    #[test]
    fn asset_names() {
        let n = |k, a| asset_name_for("v1.2.3".into(), platform(k, a));
        assert_eq!(
            n(PackageKind::Deb, "x86_64").unwrap(),
            "clotho-1.2.3-linux-amd64.deb"
        );
        assert_eq!(
            n(PackageKind::Arch, "x86_64").unwrap(),
            "clotho-1.2.3-linux-x86_64.pkg.tar.zst"
        );
        assert_eq!(
            n(PackageKind::Apk, "aarch64").unwrap(),
            "clotho-1.2.3-android-arm64-v8a.apk"
        );
        assert_eq!(
            n(PackageKind::WindowsInstaller, "x86_64").unwrap(),
            "clotho-1.2.3-windows-x64-setup.exe"
        );
        assert_eq!(n(PackageKind::Apk, "mips"), None);
        assert_eq!(n(PackageKind::Unknown, "x86_64"), None);
    }

    fn release(tag: &str, prerelease: bool, assets: &[&str]) -> RawRelease {
        RawRelease {
            tag_name: tag.into(),
            name: Some(format!("Clotho {tag}")),
            body: Some("notes".into()),
            html_url: format!("https://github.com/x/releases/{tag}"),
            published_at: None,
            draft: false,
            prerelease,
            assets: assets
                .iter()
                .map(|n| RawAsset {
                    name: n.to_string(),
                    browser_download_url: format!("https://dl/{n}"),
                    size: 10,
                })
                .collect(),
        }
    }

    #[test]
    fn picks_newest_stable_release() {
        let p = platform(PackageKind::Deb, "x86_64");
        let rels = vec![
            release("v0.3.0-rc.1", true, &[]),
            release(
                "v0.2.0",
                false,
                &["clotho-0.2.0-linux-amd64.deb", SUMS_NAME, SIG_NAME],
            ),
            release("v0.1.5", false, &[]),
            release("nonsense", false, &[]),
        ];
        let u = newest_update(rels, "0.1.0", &p).unwrap().unwrap();
        assert_eq!(u.version, "0.2.0");
        assert_eq!(u.asset.unwrap().name, "clotho-0.2.0-linux-amd64.deb");
        assert_eq!(u.sums_url.as_deref(), Some("https://dl/SHA256SUMS.txt"));
        assert!(u.signature_url.is_some());
    }

    #[test]
    fn up_to_date_returns_none() {
        let p = platform(PackageKind::Dmg, "aarch64");
        let rels = vec![release("v0.2.0", false, &[])];
        assert_eq!(newest_update(rels, "0.2.0", &p).unwrap(), None);
        assert!(newest_update(vec![], "garbage", &p).is_err());
    }

    struct Signed {
        public: String,
        sums: String,
        sig: String,
    }

    fn sign_sums(sums: &str) -> Signed {
        let kp = minisign::KeyPair::generate_unencrypted_keypair().unwrap();
        let sig = minisign::sign(Some(&kp.pk), &kp.sk, sums.as_bytes(), None, None).unwrap();
        Signed {
            public: kp.pk.to_box().unwrap().to_string(),
            sums: sums.to_string(),
            sig: sig.to_string(),
        }
    }

    fn sha_hex(data: &[u8]) -> String {
        hex(&Sha256::digest(data))
    }

    #[test]
    fn verifies_signed_checksum_list() {
        let s = sign_sums(&format!(
            "{}  clotho-1.0.0-macos.dmg\n{} *other.zip\n",
            sha_hex(b"dmg"),
            sha_hex(b"zip")
        ));
        assert_eq!(
            expected_hash(&s.public, &s.sums, &s.sig, "clotho-1.0.0-macos.dmg").unwrap(),
            sha_hex(b"dmg")
        );
        assert_eq!(
            expected_hash(&s.public, &s.sums, &s.sig, "other.zip").unwrap(),
            sha_hex(b"zip")
        );
        assert!(matches!(
            expected_hash(&s.public, &s.sums, &s.sig, "missing.apk"),
            Err(CoreError::Integrity { .. })
        ));
        // A modified list fails the signature check.
        let tampered = s.sums.replace(&sha_hex(b"dmg"), &sha_hex(b"evil"));
        assert!(matches!(
            expected_hash(&s.public, &tampered, &s.sig, "clotho-1.0.0-macos.dmg"),
            Err(CoreError::Integrity { .. })
        ));
        // A different key fails too.
        let other = sign_sums("x");
        assert!(expected_hash(&other.public, &s.sums, &s.sig, "other.zip").is_err());
    }

    #[test]
    fn rejects_unsafe_names() {
        assert!(safe_file_name("../evil").is_err());
        assert!(safe_file_name(".hidden").is_err());
        assert!(safe_file_name("a/b").is_err());
        assert!(safe_file_name("clotho-1.0.0-linux-amd64.deb").is_ok());
    }

    /// Serves fixed bodies by path until the test ends.
    fn serve(files: Vec<(&'static str, Vec<u8>)>) -> String {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let base = format!("http://{}", listener.local_addr().unwrap());
        std::thread::spawn(move || {
            for stream in listener.incoming() {
                let mut stream = stream.unwrap();
                let mut reader = BufReader::new(stream.try_clone().unwrap());
                let mut line = String::new();
                reader.read_line(&mut line).unwrap();
                loop {
                    let mut h = String::new();
                    reader.read_line(&mut h).unwrap();
                    if h == "\r\n" || h.is_empty() {
                        break;
                    }
                }
                let path = line.split_whitespace().nth(1).unwrap_or("/").to_string();
                let body = files
                    .iter()
                    .find(|(p, _)| *p == path)
                    .map(|(_, b)| b.clone());
                let (status, body) = match body {
                    Some(b) => ("200 OK", b),
                    None => ("404 Not Found", b"nope".to_vec()),
                };
                let head = format!(
                    "HTTP/1.1 {status}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                    body.len()
                );
                stream.write_all(head.as_bytes()).unwrap();
                stream.write_all(&body).unwrap();
            }
        });
        base
    }

    fn update_for(base: &str, name: &str) -> UpdateInfo {
        UpdateInfo {
            version: "1.0.0".into(),
            tag: "v1.0.0".into(),
            name: "Clotho 1.0.0".into(),
            notes: String::new(),
            html_url: String::new(),
            published_at: None,
            asset: Some(ReleaseAsset {
                name: name.into(),
                url: format!("{base}/pkg"),
                size: 0,
            }),
            sums_url: Some(format!("{base}/sums")),
            signature_url: Some(format!("{base}/sig")),
        }
    }

    #[test]
    fn downloads_and_verifies() {
        let payload = vec![7u8; 300_000];
        let name = "clotho-1.0.0-linux-x86_64.tar.gz";
        let s = sign_sums(&format!("{}  {name}\n", sha_hex(&payload)));
        let base = serve(vec![
            ("/sums", s.sums.clone().into_bytes()),
            ("/sig", s.sig.clone().into_bytes()),
            ("/pkg", payload.clone()),
        ]);
        let dir = tempfile::tempdir().unwrap();
        let mut events = vec![];
        let done = download_verified(
            &s.public,
            &update_for(&base, name),
            dir.path().to_str().unwrap(),
            |p| events.push(p),
        )
        .unwrap();
        let DownloadProgress::Done { path, sha256 } = done else {
            panic!("not done")
        };
        assert_eq!(std::fs::read(&path).unwrap(), payload);
        assert_eq!(sha256, sha_hex(&payload));
        assert_eq!(sha256_file(path).unwrap(), sha256);
        assert!(events.contains(&DownloadProgress::Verifying));
        assert!(events.iter().any(|e| matches!(
            e,
            DownloadProgress::Downloading {
                received: 300_000,
                total: 300_000
            }
        )));
    }

    #[test]
    fn tampered_download_is_deleted() {
        let name = "clotho-1.0.0-linux-x86_64.tar.gz";
        let s = sign_sums(&format!("{}  {name}\n", sha_hex(b"genuine")));
        let base = serve(vec![
            ("/sums", s.sums.clone().into_bytes()),
            ("/sig", s.sig.clone().into_bytes()),
            ("/pkg", b"malicious".to_vec()),
        ]);
        let dir = tempfile::tempdir().unwrap();
        let r = download_verified(
            &s.public,
            &update_for(&base, name),
            dir.path().to_str().unwrap(),
            |_| {},
        );
        assert!(matches!(r, Err(CoreError::Integrity { .. })));
        assert_eq!(std::fs::read_dir(dir.path()).unwrap().count(), 0);
    }

    #[test]
    fn unsigned_release_is_refused_before_download() {
        let mut u = update_for("http://127.0.0.1:9", "x.dmg");
        u.signature_url = None;
        let dir = tempfile::tempdir().unwrap();
        assert!(matches!(
            download_verified(UPDATE_PUBLIC_KEY, &u, dir.path().to_str().unwrap(), |_| {}),
            Err(CoreError::Integrity { .. })
        ));
    }
}
