"""Builds the GitHub Pages download page for a release.

usage: python3 build.py <version> <SHA256SUMS.txt> <notes.md> <out dir>
"""
import html
import pathlib
import sys

REPO = "aimatochysia/clotho"

version, sums_path, notes_path, out_dir = sys.argv[1:5]
sums = {}
for line in pathlib.Path(sums_path).read_text().splitlines():
    parts = line.split(maxsplit=1)
    if len(parts) == 2:
        sums[parts[1].lstrip("*")] = parts[0]

base = f"https://github.com/{REPO}/releases/download/v{version}"
groups = [
    ("Windows", [
        (f"clotho-{version}-windows-x64-setup.exe", "Installer (recommended)"),
        (f"clotho-{version}-windows-x64.zip", "Portable zip"),
    ]),
    ("macOS", [(f"clotho-{version}-macos.dmg", "Disk image (Apple silicon and Intel)")]),
    ("Linux", [
        (f"clotho-{version}-linux-amd64.deb", "Debian / Ubuntu (.deb)"),
        (f"clotho-{version}-linux-x86_64.pkg.tar.zst", "Arch Linux (pacman -U)"),
        (f"clotho-{version}-linux-x86_64.tar.gz", "Portable tar.gz"),
    ]),
    ("Android", [
        (f"clotho-{version}-android-arm64-v8a.apk", "Most phones (arm64)"),
        (f"clotho-{version}-android-armeabi-v7a.apk", "Older phones (32-bit ARM)"),
        (f"clotho-{version}-android-x86_64.apk", "x86_64 devices and emulators"),
    ]),
]

cards = []
for title, files in groups:
    rows = []
    for name, label in files:
        if name not in sums:
            continue
        rows.append(
            f'<li><a class="dl" href="{base}/{html.escape(name)}">{html.escape(label)}</a>'
            f'<span class="file">{html.escape(name)}</span>'
            f'<code class="sum">SHA-256 {sums[name]}</code></li>'
        )
    if rows:
        cards.append(f'<section class="card"><h2>{title}</h2><ul>{"".join(rows)}</ul></section>')

notes = html.escape(pathlib.Path(notes_path).read_text().strip() or "No notes.")
page = (pathlib.Path(__file__).parent / "index.html").read_text()
page = (
    page.replace("{{VERSION}}", html.escape(version))
    .replace("{{CARDS}}", "\n".join(cards))
    .replace("{{NOTES}}", notes)
    .replace("{{BASE}}", base)
    .replace("{{REPO}}", REPO)
)
out = pathlib.Path(out_dir)
out.mkdir(parents=True, exist_ok=True)
(out / "index.html").write_text(page)
(out / "clotho-update.pub").write_text(
    (pathlib.Path(__file__).parent.parent / "clotho-update.pub").read_text()
)
print(f"wrote {out / 'index.html'}")
