use crate::error::CoreResult;

/// Version of the Rust core, taken from Cargo.toml at build time.
#[flutter_rust_bridge::frb(sync)]
pub fn core_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

/// Version of the statically linked libgit2.
#[flutter_rust_bridge::frb(sync)]
pub fn libgit2_version() -> String {
    let v = git2::Version::get();
    let (major, minor, patch) = v.libgit2_version();
    format!("{major}.{minor}.{patch}")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
    trust_shared_storage();
}

/// libgit2, like Git, refuses repositories owned by another user. Android's
/// shared storage (/storage/emulated/0) is always owned by a system user,
/// never by the app, so every repository there would be refused. Android
/// already sandboxes each app, so the check protects nothing there.
fn trust_shared_storage() {
    #[cfg(target_os = "android")]
    // SAFETY: called once at start-up, before any repository is opened.
    unsafe {
        let _ = git2::opts::set_verify_owner_validation(false);
    }
}

/// Where Android keeps the trusted CA certificates (one PEM file each). The
/// APEX copy is the up-to-date one on Android 14+.
#[cfg(target_os = "android")]
const ANDROID_CA_DIRS: [&str; 2] = [
    "/apex/com.android.conscrypt/cacerts",
    "/system/etc/security/cacerts",
];

/// Points libgit2's TLS at the system's trusted certificates. Needed on
/// Android: the bundled OpenSSL looks for a Linux CA file that does not exist
/// there, so every HTTPS push or fetch failed with "the SSL certificate is
/// invalid". The certificates are gathered into `cache_dir/cacert.pem`.
/// Elsewhere this does nothing (the OS or the usual Linux paths are used).
pub fn configure_tls(cache_dir: String) -> CoreResult<()> {
    #[cfg(target_os = "android")]
    {
        let dirs: Vec<std::path::PathBuf> = ANDROID_CA_DIRS
            .iter()
            .map(|d| std::path::PathBuf::from(*d))
            .collect();
        let bundle = std::path::Path::new(&cache_dir).join("cacert.pem");
        if write_ca_bundle(&dirs, &bundle)? > 0 {
            // SAFETY: called at start-up, before any network operation.
            unsafe { git2::opts::set_ssl_cert_file(bundle.as_path())? };
        }
    }
    #[cfg(not(target_os = "android"))]
    let _ = cache_dir;
    Ok(())
}

/// Collects the PEM certificates of every file in the first existing
/// directory of `dirs` into `out`. Returns how many were written.
#[cfg(any(target_os = "android", test))]
fn write_ca_bundle(dirs: &[std::path::PathBuf], out: &std::path::Path) -> CoreResult<usize> {
    const BEGIN: &str = "-----BEGIN CERTIFICATE-----";
    const END: &str = "-----END CERTIFICATE-----";
    let Some(dir) = dirs.iter().find(|d| d.is_dir()) else {
        return Ok(0);
    };
    let mut pem = String::new();
    let mut count = 0;
    let mut entries: Vec<_> = std::fs::read_dir(dir)?
        .flatten()
        .map(|e| e.path())
        .collect();
    entries.sort();
    for path in entries {
        let Ok(text) = std::fs::read_to_string(&path) else {
            continue;
        };
        // Android's files hold the PEM block followed by a text dump.
        let mut rest = text.as_str();
        while let Some(start) = rest.find(BEGIN) {
            let Some(len) = rest[start..].find(END) else {
                break;
            };
            let end = start + len + END.len();
            pem.push_str(&rest[start..end]);
            pem.push('\n');
            count += 1;
            rest = &rest[end..];
        }
    }
    if count > 0 {
        if let Some(parent) = out.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let tmp = out.with_extension("pem.tmp");
        std::fs::write(&tmp, pem)?;
        std::fs::rename(&tmp, out)?;
    }
    Ok(count)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ca_bundle_keeps_only_pem_blocks() {
        let d = tempfile::tempdir().unwrap();
        let certs = d.path().join("cacerts");
        std::fs::create_dir_all(&certs).unwrap();
        let block =
            |n: &str| format!("-----BEGIN CERTIFICATE-----\n{n}\n-----END CERTIFICATE-----");
        std::fs::write(
            certs.join("a.0"),
            format!("{}\nCertificate:\n    Data: text dump\n", block("AAA")),
        )
        .unwrap();
        std::fs::write(certs.join("b.0"), block("BBB")).unwrap();
        let out = d.path().join("cache/cacert.pem");
        let missing = d.path().join("nope");
        let n = write_ca_bundle(&[missing, certs], &out).unwrap();
        assert_eq!(n, 2);
        let text = std::fs::read_to_string(out).unwrap();
        assert!(!text.contains("text dump"));
        assert_eq!(text, format!("{}\n{}\n", block("AAA"), block("BBB")));
        let none = write_ca_bundle(&[d.path().join("x")], &d.path().join("y.pem")).unwrap();
        assert_eq!(none, 0);
    }

    #[test]
    fn versions_are_not_empty() {
        assert!(!core_version().is_empty());
        assert!(libgit2_version().split('.').count() == 3);
    }
}
