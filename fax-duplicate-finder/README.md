# Fax Duplicate Finder

Scans a folder or share drive (recursively) for duplicate fax documents (`.tif/.tiff/.pdf/.png/.jpg`).

| Match type | What it catches |
|---|---|
| `exact`  | Byte-identical copies (SHA-256) |
| `visual` | Same pages but different files: the same fax received twice with a different header timestamp, re-saved, or converted TIFF <-> PDF |

The fax header strip (top 6%) and footer (bottom 3%) are ignored, so different send times and page stamps don't stop a match.

## Setup
```
pip install -r requirements.txt
```

## Usage
```
python find_fax_duplicates.py "\\server\share\Faxes"                 # report only -> fax_duplicates.csv
python find_fax_duplicates.py "Z:\Faxes" --exact-only                # fastest, identical files only
python find_fax_duplicates.py "Z:\Faxes" --threshold 0.06            # stricter visual match
python find_fax_duplicates.py "Z:\Faxes" --move-duplicates "Z:\Dupes_Review"
```

* It never deletes anything. `--move-duplicates` moves the extra copies and keeps the oldest file of each group where it was.
* Put the review folder **outside** the scanned folder.
* Files it can't read (corrupt, locked) are listed in `fax_duplicates.errors.csv`.
* `--threshold` (default `0.10`) is the share of a page's hash that may differ. Run a report on a sample first and check the `visual` rows before you move anything.

## Running from Power Automate Desktop
Use a **Run PowerShell script** or **Run DOS command** action:
```
python "C:\Scripts\find_fax_duplicates.py" "\\server\share\Faxes" --report "C:\Reports\fax_dupes.csv"
```
Then read the CSV with **Read from CSV file** and loop over the rows (email a summary, move files, open tickets, and so on).
Don't use PAD's built-in "Run Python script" action. It runs the old IronPython 2.7, which can't load these libraries.
