#!/usr/bin/env python3
"""Export only reviewed code and documentation, without invoking Git."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parent.parent
PUBLIC_FILES = (
    ".gitignore", "LICENSE", "README.md", "THIRD_PARTY_NOTICES.md",
    "docs/ASSETS.md", "docs/OPEN_SOURCE_GUIDE.md", "docs/releases/v0.1.0.md", "docs/releases/v0.1.1.md",
    ".github/workflows/windows-release.yml", "src/prepare_windows.py", "src/verify_windows.cjs",
    "src/main.swift", "src/PetMotion.swift", "src/PetSpeech.swift",
    "src/Info.plist", "src/build.sh", "src/chroma_key.py",
    "src/chroma_key_chibi.py", "src/make_icon.py", "src/make_motion.py",
    "src/make_mouths.py", "src/export_source.py",
    "windows-app/.gitignore", "windows-app/README.md", "windows-app/NOTICE.txt",
    "windows-app/package.json", "windows-app/package-lock.json",
    "windows-app/main.cjs", "windows-app/preload.cjs", "windows-app/renderer.js",
    "windows-app/settings.js", "windows-app/index.html", "windows-app/settings.html",
    "windows-app/pet.css", "windows-app/settings.css",
)


def main():
    # Check all inputs before replacing a previous export. Do not follow symlinks
    # to files outside the project, even when an allowlisted name is used.
    for name in PUBLIC_FILES:
        path = ROOT / name
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(ROOT):
            raise SystemExit(f"Missing or unsafe public file: {name}")
    output = ROOT / "dist" / "MikuDeskPet-source.zip"
    output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
        for name in PUBLIC_FILES:
            entry = ZipInfo(f"MikuDeskPet/{name}")
            entry.compress_type = ZIP_DEFLATED
            entry.create_system = 3
            mode = 0o755 if name.endswith(".sh") else 0o644
            entry.external_attr = (0o100000 | mode) << 16
            archive.writestr(entry, (ROOT / name).read_bytes())
    print(f"Exported {len(PUBLIC_FILES)} code/documentation files to dist/MikuDeskPet-source.zip")
    print("Artwork, audio, icons, dependencies, backups and installers are excluded.")


if __name__ == "__main__":
    main()
