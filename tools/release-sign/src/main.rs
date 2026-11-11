//! `release-sign <file> [trusted comment]`
//!
//! Signs `<file>` with the minisign secret key in `UPDATE_SIGNING_KEY`
//! (the full contents of the `.key` file), unlocked with
//! `UPDATE_SIGNING_PASSWORD`, and writes `<file>.minisig`. With
//! `UPDATE_PUBLIC_KEY_FILE` set, the signature is checked against that key
//! before it is written, so a wrong secret fails the release.
use std::env;
use std::fs::File;
use std::process::ExitCode;

use minisign::{PublicKeyBox, SecretKeyBox, SignatureBox};

fn run() -> Result<(), String> {
    let mut args = env::args().skip(1);
    let file = args
        .next()
        .ok_or("usage: release-sign <file> [trusted comment]")?;
    let comment = args.next();
    let key = env::var("UPDATE_SIGNING_KEY").map_err(|_| "UPDATE_SIGNING_KEY is not set")?;
    // Never None: minisign would then prompt on a terminal and hang in CI.
    let password = Some(env::var("UPDATE_SIGNING_PASSWORD").unwrap_or_default());
    let key = normalize_key(&key)?;
    let sk = SecretKeyBox::from_string(&key)
        .and_then(|b| b.into_secret_key(password))
        .map_err(|e| format!("cannot unlock the signing key: {e}"))?;

    let pk = match env::var("UPDATE_PUBLIC_KEY_FILE") {
        Ok(path) => {
            let text = std::fs::read_to_string(&path).map_err(|e| format!("{path}: {e}"))?;
            let pk = PublicKeyBox::from_string(text.replace("\r\n", "\n").trim())
                .and_then(|b| b.into_public_key())
                .map_err(|e| format!("bad public key in {path}: {e}"))?;
            Some(pk)
        }
        Err(_) => None,
    };

    let data = File::open(&file).map_err(|e| format!("{file}: {e}"))?;
    let sig = minisign::sign(pk.as_ref(), &sk, data, comment.as_deref(), None)
        .map_err(|e| format!("signing failed: {e}"))?;
    if let Some(pk) = &pk {
        let check = SignatureBox::from_string(&sig.to_string()).map_err(|e| e.to_string())?;
        let data = File::open(&file).map_err(|e| format!("{file}: {e}"))?;
        minisign::verify(pk, &check, data, true, false, false)
            .map_err(|_| "the signing key does not match packaging/clotho-update.pub")?;
    }
    let out = format!("{file}.minisig");
    std::fs::write(&out, sig.to_string()).map_err(|e| format!("{out}: {e}"))?;
    println!("wrote {out}");
    Ok(())
}

/// Accepts the `.key` file as saved by minisign, but also just its key line,
/// or both lines joined into one (easy to end up with when pasting into the
/// GitHub secrets form), and rebuilds the two-line format.
fn normalize_key(raw: &str) -> Result<String, String> {
    let b64 = raw
        .split_whitespace()
        .filter(|t| {
            t.len() > 100
                && t.chars()
                    .all(|c| c.is_ascii_alphanumeric() || matches!(c, '+' | '/' | '='))
        })
        .max_by_key(|t| t.len())
        .ok_or("UPDATE_SIGNING_KEY does not contain a minisign secret key")?;
    Ok(format!(
        "untrusted comment: minisign encrypted secret key\n{b64}\n"
    ))
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("release-sign: {e}");
            ExitCode::FAILURE
        }
    }
}
