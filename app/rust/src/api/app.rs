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
/// APEX copy is the up-to-date one on Android 14+; both are read in case one
/// is missing or unreadable.
#[cfg(target_os = "android")]
const ANDROID_CA_DIRS: [&str; 2] = [
    "/apex/com.android.conscrypt/cacerts",
    "/system/etc/security/cacerts",
];

/// Points libgit2's TLS at trusted certificates. Needed on Android, where the
/// bundled OpenSSL finds none, so every HTTPS push or fetch failed with "the
/// SSL certificate is invalid". Elsewhere this does nothing (the OS or the
/// usual Linux paths are used). `cache_dir` is kept for API stability.
pub fn configure_tls(cache_dir: String) -> CoreResult<()> {
    let _ = cache_dir;
    #[cfg(target_os = "android")]
    {
        let dirs: Vec<std::path::PathBuf> = ANDROID_CA_DIRS
            .iter()
            .map(std::path::PathBuf::from)
            .collect();
        crate::tls::install(&dirs);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn versions_are_not_empty() {
        assert!(!core_version().is_empty());
        assert!(libgit2_version().split('.').count() == 3);
    }
}
