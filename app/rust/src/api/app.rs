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
