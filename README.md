# Clotho

A desktop and Android app for managing Git and GitHub repositories that live anywhere on your disk. The UI is Flutter; all Git, GitHub and update logic lives in a Rust core (`app/rust`) called through [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge).

Platforms: Linux (.deb, Arch, tar.gz), Windows, macOS, Android.

## Layout

```
app/                 Flutter app
app/rust/            clotho_core Rust crate (git2/libgit2, vendored)
app/rust_builder/    Cargokit glue that builds the crate during `flutter build`
packaging/           release packaging files and the update-signing public key
.github/workflows/   CI
```

## Development

Requirements: Flutter 3.47 (stable), Rust stable via rustup, and the usual platform toolchain (GTK 3 and libsecret dev libraries on Linux, Visual Studio on Windows, Xcode on macOS, Android SDK for Android).

```sh
cd app
flutter pub get
flutter run                      # builds the Rust crate automatically
flutter test                     # Dart unit and widget tests
(cd rust && cargo test)          # Rust tests
```

Browser sign-in to GitHub needs the OAuth App client id at build time; without it only personal access tokens work:

```sh
flutter run --dart-define=CLOTHO_GITHUB_CLIENT_ID=Ov23li...
```

The token is stored in the OS keychain (Keychain, Credential Manager, libsecret, Android Keystore) and is only ever sent to `github.com`.

After changing anything under `app/rust/src/api/`, regenerate the bindings:

```sh
cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked
cd app && flutter_rust_bridge_codegen generate
```

Commits follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `perf:` …); release notes are generated from them.

## Releasing

Releases are made from the **Actions** tab: run **Release** on `main`, pick a bump (patch, minor or major) or type an exact version. The workflow:

1. works out the next version from the latest `v*` tag and writes release notes from the Conventional Commits since then (git-cliff, `cliff.toml`);
2. builds the Linux `.deb`, Arch `.pkg.tar.zst` and `tar.gz`, the Android APKs (signed with the release key), the macOS `.dmg`, and the Windows installer and zip;
3. writes `SHA256SUMS.txt`, signs it with the minisign key (`SHA256SUMS.txt.minisig`), and publishes everything as a GitHub release tagged `vX.Y.Z`;
4. updates the download page on GitHub Pages.

Pull requests that change packaging run the same pipeline as a dry run (version 0.0.<run number>, nothing published; the packages are kept as workflow artifacts for testing). The app checks for new releases on start, downloads the package for its platform, and installs it only if both the signature and the SHA-256 match (`app/rust/src/api/update.rs`).

