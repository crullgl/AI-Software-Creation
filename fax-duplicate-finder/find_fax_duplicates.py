#!/usr/bin/env python3
"""
find_fax_duplicates.py - Find duplicate digital fax documents in a folder / share drive.

Two levels of matching:
  1. EXACT   - byte-for-byte identical files (SHA-256 hash).
  2. VISUAL  - same pages but different files, e.g. the same fax received twice,
               re-saved, or converted TIFF<->PDF. Each page is rendered, the fax
               header strip (sender / timestamp / "Page 1 of 3" line) is cropped
               off, and a perceptual "difference hash" is compared.

Read-only by default: it writes a CSV report and never deletes anything.
Optionally use --move-duplicates to MOVE (not delete) the extra copies into a
review folder, keeping the oldest file of each group in place.

Supported: .tif .tiff .pdf .png .jpg .jpeg
Requires : Python 3.9+, Pillow, numpy. PDF support also needs PyMuPDF.
           pip install pillow numpy pymupdf

Examples:
  python find_fax_duplicates.py "\\\\server\\share\\Faxes"
  python find_fax_duplicates.py "Z:\\Faxes" --report dupes.csv --threshold 0.08
  python find_fax_duplicates.py "Z:\\Faxes" --exact-only
  python find_fax_duplicates.py "Z:\\Faxes" --move-duplicates "Z:\\Faxes\\_duplicates_review"
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import os
import shutil
import sys
from collections import defaultdict
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image, ImageSequence

try:
    import pymupdf as fitz  # PyMuPDF >= 1.24
except ImportError:
    try:
        import fitz  # older PyMuPDF
    except ImportError:  # PDF support is optional
        fitz = None

Image.MAX_IMAGE_PIXELS = None  # large fax TIFFs are fine

EXTENSIONS = {".tif", ".tiff", ".pdf", ".png", ".jpg", ".jpeg"}
HASH_SIZE = 16          # 16x16 = 256-bit hash per page
HEADER_CROP = 0.06      # top 6% of page = fax transmission header line
FOOTER_CROP = 0.03      # bottom 3% (some machines stamp a footer)
MAX_PAGES = 50          # pages hashed per document (keeps huge files fast)


@dataclass
class FaxFile:
    path: str
    size: int
    modified: float
    sha256: str = ""
    pages: int = 0
    page_hashes: list = field(default_factory=list)  # list of np.bool_ arrays
    error: str = ""


# --------------------------------------------------------------------------- #
# Hashing
# --------------------------------------------------------------------------- #
def sha256_file(path: str, chunk: int = 1 << 20) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while block := f.read(chunk):
            h.update(block)
    return h.hexdigest()


def dhash(img: Image.Image) -> np.ndarray:
    """Difference hash of one page, ignoring the fax header/footer strips."""
    img = img.convert("L")
    w, h = img.size
    top, bottom = int(h * HEADER_CROP), int(h * (1 - FOOTER_CROP))
    if bottom - top > 50:
        img = img.crop((0, top, w, bottom))
    small = img.resize((HASH_SIZE + 1, HASH_SIZE), Image.Resampling.LANCZOS)
    px = np.asarray(small, dtype=np.int16)
    return (px[:, 1:] > px[:, :-1]).flatten()


def iter_pages(path: str):
    ext = Path(path).suffix.lower()
    if ext == ".pdf":
        if fitz is None:
            raise RuntimeError("PyMuPDF not installed (pip install pymupdf)")
        with fitz.open(path) as doc:
            for i, page in enumerate(doc):
                if i >= MAX_PAGES:
                    break
                pix = page.get_pixmap(dpi=72, colorspace=fitz.csGRAY)
                yield Image.frombytes("L", (pix.width, pix.height), pix.samples)
    else:
        with Image.open(path) as im:
            for i, frame in enumerate(ImageSequence.Iterator(im)):
                if i >= MAX_PAGES:
                    break
                yield frame.copy()


def analyze(path: str, size: int, modified: float, exact_only: bool) -> FaxFile:
    ff = FaxFile(path=path, size=size, modified=modified)
    try:
        ff.sha256 = sha256_file(path)
        if not exact_only:
            ff.page_hashes = [dhash(p) for p in iter_pages(path)]
            ff.pages = len(ff.page_hashes)
    except Exception as e:  # corrupt / locked / unsupported file
        ff.error = f"{type(e).__name__}: {e}"
    return ff


# --------------------------------------------------------------------------- #
# Grouping
# --------------------------------------------------------------------------- #
class UnionFind:
    def __init__(self, n):
        self.parent = list(range(n))

    def find(self, x):
        while self.parent[x] != x:
            self.parent[x] = self.parent[self.parent[x]]
            x = self.parent[x]
        return x

    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.parent[rb] = ra


def find_groups(files: list[FaxFile], threshold: float, exact_only: bool):
    """Return {root_index: [indices]} and {index: match_type}."""
    uf = UnionFind(len(files))
    match_type = {}

    # 1) exact
    by_sha = defaultdict(list)
    for i, f in enumerate(files):
        if f.sha256:
            by_sha[f.sha256].append(i)
    for idxs in by_sha.values():
        for j in idxs[1:]:
            uf.union(idxs[0], j)
            match_type[j] = match_type[idxs[0]] = "exact"

    # 2) visual: compare documents with the same page count
    if not exact_only:
        max_bits = int(threshold * HASH_SIZE * HASH_SIZE)
        by_pages = defaultdict(list)
        for sha_idxs in by_sha.values():       # one representative per exact group
            i = sha_idxs[0]
            if files[i].pages:
                by_pages[files[i].pages].append(i)

        for idxs in by_pages.values():
            if len(idxs) < 2:
                continue
            # vectorised first-page screen, then confirm every page
            first = np.stack([files[i].page_hashes[0] for i in idxs])
            for a in range(len(idxs) - 1):
                dist = np.count_nonzero(first[a + 1:] != first[a], axis=1)
                for off in np.nonzero(dist <= max_bits)[0]:
                    b = a + 1 + off
                    fa, fb = files[idxs[a]], files[idxs[b]]
                    if all(np.count_nonzero(pa != pb) <= max_bits
                           for pa, pb in zip(fa.page_hashes, fb.page_hashes)):
                        uf.union(idxs[a], idxs[b])
                        for k in (idxs[a], idxs[b]):
                            match_type.setdefault(k, "visual")

    groups = defaultdict(list)
    for i in range(len(files)):
        groups[uf.find(i)].append(i)
    return {r: m for r, m in groups.items() if len(m) > 1}, match_type


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
def scan(root: Path):
    for dirpath, _dirs, names in os.walk(root):
        for n in names:
            if Path(n).suffix.lower() in EXTENSIONS:
                p = os.path.join(dirpath, n)
                try:
                    st = os.stat(p)
                    yield p, st.st_size, st.st_mtime
                except OSError:
                    pass


def main(argv=None):
    ap = argparse.ArgumentParser(description="Find duplicate fax documents (TIFF/PDF).")
    ap.add_argument("folder", help="Folder or UNC share path to scan (recursive)")
    ap.add_argument("--report", default="fax_duplicates.csv", help="CSV output path")
    ap.add_argument("--threshold", type=float, default=0.10,
                    help="Max fraction of differing hash bits per page for a visual "
                         "match (0.0-0.25). Lower = stricter. Default 0.10")
    ap.add_argument("--exact-only", action="store_true",
                    help="Only find byte-identical files (fastest)")
    ap.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument("--move-duplicates", metavar="DIR",
                    help="Move extra copies (all but the oldest in each group) into DIR")
    args = ap.parse_args(argv)

    root = Path(args.folder)
    if not root.is_dir():
        sys.exit(f"Not a folder: {root}")
    if fitz is None and not args.exact_only:
        print("NOTE: PyMuPDF not installed - PDFs get exact matching only.", file=sys.stderr)

    entries = list(scan(root))
    print(f"Found {len(entries)} fax files under {root}")

    files: list[FaxFile] = []
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        futs = [pool.submit(analyze, p, s, m, args.exact_only) for p, s, m in entries]
        for n, fut in enumerate(as_completed(futs), 1):
            files.append(fut.result())
            if n % 250 == 0 or n == len(futs):
                print(f"  analyzed {n}/{len(futs)}", end="\r")
    print()
    files.sort(key=lambda f: f.path)

    groups, match_type = find_groups(files, args.threshold, args.exact_only)

    rows, to_move = [], []
    for gid, idxs in enumerate(sorted(groups.values(), key=lambda g: files[g[0]].path), 1):
        members = sorted((files[i] for i in idxs), key=lambda f: f.modified)
        keeper = members[0]
        for rank, f in enumerate(members):
            action = "KEEP (oldest)" if rank == 0 else "duplicate"
            gtype = "" if rank == 0 else ("exact" if f.sha256 == keeper.sha256 else "visual")
            if rank:
                to_move.append(f.path)
            rows.append([gid, gtype, action, f.path, f.size,
                         datetime.fromtimestamp(f.modified).isoformat(" ", "seconds"),
                         f.pages or "", f.sha256])

    with open(args.report, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["group", "match_type", "suggested_action", "path", "size_bytes",
                    "modified", "pages", "sha256"])
        w.writerows(rows)

    errors = [f for f in files if f.error]
    if errors:
        err_path = Path(args.report).with_suffix(".errors.csv")
        with open(err_path, "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow(["path", "error"])
            w.writerows([f.path, f.error] for f in errors)
        print(f"{len(errors)} files could not be read -> {err_path}")

    print(f"{len(groups)} duplicate groups, {len(to_move)} extra copies -> {args.report}")

    if args.move_duplicates and to_move:
        dest_root = Path(args.move_duplicates)
        for src in to_move:
            rel = Path(src).resolve().relative_to(root.resolve())
            dest = dest_root / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(src, dest)
        print(f"Moved {len(to_move)} duplicates into {dest_root} (nothing deleted)")


if __name__ == "__main__":
    main()
