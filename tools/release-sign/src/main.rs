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
    let password = env::var("UPDATE_SIGNING_PASSWORD")
        .ok()
        .filter(|p| !p.is_empty());
    let key = key.replace("\r\n", "\n");
    let sk = SecretKeyBox::from_string(key.trim())
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

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("release-sign: {e}");
            ExitCode::FAILURE
        }
    }
}
