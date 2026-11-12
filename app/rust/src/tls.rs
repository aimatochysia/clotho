//! Trusted certificates for libgit2's OpenSSL on Android.
//!
//! The bundled OpenSSL looks for a Linux CA file that Android does not have,
//! so every HTTPS fetch or push failed with "the SSL certificate is invalid".
//! Each certificate is parsed and added to libgit2's trust store one by one,
//! so a single odd file cannot spoil the rest. Mozilla's root list is added
//! too, in case the system store cannot be read.

use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

use foreign_types_shared::ForeignType;
use openssl::x509::X509;

/// How many certificates were trusted, shown in TLS errors to help diagnose.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub(crate) struct TlsSummary {
    pub system: u32,
    pub bundled: u32,
}

static SUMMARY: Mutex<Option<TlsSummary>> = Mutex::new(None);

/// Loads the system certificates from every directory in `dirs` plus the
/// bundled Mozilla roots. Safe to call more than once; later calls add
/// nothing new.
pub(crate) fn install(dirs: &[PathBuf]) -> TlsSummary {
    let mut seen: HashSet<Vec<u8>> = HashSet::new();
    let mut summary = TlsSummary::default();
    for dir in dirs {
        let Ok(entries) = std::fs::read_dir(dir) else {
            continue;
        };
        let mut files: Vec<PathBuf> = entries.flatten().map(|e| e.path()).collect();
        files.sort();
        for file in files {
            for cert in certs_in(&file) {
                if add(&cert, &mut seen) {
                    summary.system += 1;
                }
            }
        }
    }
    for der in webpki_root_certs::TLS_SERVER_ROOT_CERTS {
        if let Ok(cert) = X509::from_der(der.as_ref()) {
            if add(&cert, &mut seen) {
                summary.bundled += 1;
            }
        }
    }
    *SUMMARY.lock().unwrap_or_else(|e| e.into_inner()) = Some(summary);
    summary
}

/// What `install` trusted, if it ran.
pub(crate) fn summary() -> Option<TlsSummary> {
    *SUMMARY.lock().unwrap_or_else(|e| e.into_inner())
}

/// Certificates in a PEM file. Android's files hold one PEM block followed by
/// a text dump, which the PEM reader skips.
fn certs_in(file: &Path) -> Vec<X509> {
    std::fs::read(file)
        .ok()
        .and_then(|bytes| X509::stack_from_pem(&bytes).ok())
        .unwrap_or_default()
}

/// Adds `cert` to libgit2's store unless an identical one was added already.
fn add(cert: &X509, seen: &mut HashSet<Vec<u8>>) -> bool {
    let Ok(der) = cert.to_der() else {
        return false;
    };
    if !seen.insert(der) {
        return false;
    }
    libgit2_sys::init();
    // SAFETY: libgit2 is initialised and takes its own reference to the
    // certificate (X509_STORE_add_cert), so ours can be freed afterwards.
    let rc = unsafe {
        libgit2_sys::git_libgit2_opts(
            libgit2_sys::GIT_OPT_ADD_SSL_X509_CERT as std::os::raw::c_int,
            cert.as_ptr(),
        )
    };
    rc == 0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn installs_system_and_bundled_roots() {
        let d = tempfile::tempdir().unwrap();
        let certs = d.path().join("cacerts");
        std::fs::create_dir_all(&certs).unwrap();
        let first = X509::from_der(webpki_root_certs::TLS_SERVER_ROOT_CERTS[0].as_ref()).unwrap();
        let mut file = first.to_pem().unwrap();
        file.extend_from_slice(b"Certificate:\n    Data: text dump\n");
        std::fs::write(certs.join("a.0"), file).unwrap();
        std::fs::write(
            certs.join("broken.0"),
            b"-----BEGIN CERTIFICATE-----\nnope\n",
        )
        .unwrap();
        let missing = d.path().join("missing");
        let got = install(&[missing, certs]);
        assert_eq!(got.system, 1);
        let total = webpki_root_certs::TLS_SERVER_ROOT_CERTS.len() as u32;
        assert_eq!(got.bundled, total - 1);
        assert_eq!(summary(), Some(got));
    }
}
