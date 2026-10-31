#!/usr/bin/env python3
"""Split a large Studio snapshot into GitHub-connector-friendly text parts.

The original snapshot.json remains untouched and can be reconstructed by
concatenating parts in numeric order. Each part is UTF-8, <= 64 KiB.
"""
from pathlib import Path
import hashlib
import json
import shutil

SOURCE = Path("studio-export/snapshot.json")
DEST = Path("studio-export/readable")
MAX_BYTES = 60 * 1024


def main():
    if not SOURCE.is_file():
        raise SystemExit("Missing studio-export/snapshot.json")
    raw = SOURCE.read_bytes()
    text = raw.decode("utf-8")
    # Fail visibly rather than publishing a split of corrupt JSON.
    json.loads(text)

    DEST.mkdir(parents=True, exist_ok=True)
    for old in DEST.glob("part-*.txt"):
        old.unlink()

    # Keep whole lines together whenever possible. All output is byte-safe.
    parts = []
    current = []
    size = 0
    for line in text.splitlines(keepends=True):
        for piece in line.splitlines(keepends=True) if len(line.encode("utf-8")) <= MAX_BYTES else _split_utf8(line):
            n = len(piece.encode("utf-8"))
            if current and size + n > MAX_BYTES:
                parts.append("".join(current))
                current, size = [], 0
            current.append(piece)
            size += n
    if current:
        parts.append("".join(current))

    for index, part in enumerate(parts, 1):
        (DEST / f"part-{index:04d}.txt").write_bytes(part.encode("utf-8"))

    manifest = {
        "source": str(SOURCE),
        "sha256": hashlib.sha256(raw).hexdigest(),
        "size_bytes": len(raw),
        "part_count": len(parts),
        "part_order": "part-0001.txt, part-0002.txt, ...",
        "format": "UTF-8 text fragments; concatenate in order to reconstruct original JSON",
    }
    (DEST / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    assert b"".join(p.encode("utf-8") for p in parts) == raw


def _split_utf8(line):
    chunk = ""
    count = 0
    for ch in line:
        n = len(ch.encode("utf-8"))
        if count + n > MAX_BYTES:
            yield chunk
            chunk, count = "", 0
        chunk += ch
        count += n
    if chunk:
        yield chunk


if __name__ == "__main__":
    main()
