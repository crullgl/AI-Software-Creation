# Fax Duplicate Finder

Finds duplicate fax documents (`.tif/.tiff/.pdf/.png/.jpg`) on a share drive and emails a report through
Power Automate Desktop. **Nothing is ever deleted.** In Move mode, extra copies go to a review folder.

| Match type | What it catches |
|---|---|
| `exact`  | Byte-identical copies |
| `visual` | Same pages but a different file: the same fax received twice (different header timestamp), re-saved, or converted TIFF <-> PDF |

## What's in this folder
| File | What it's for |
|---|---|
| `find_fax_duplicates.py` | The engine. Scans the folder, writes the CSV report, optionally moves copies |
| `run_fax_dedupe.ps1` | Wrapper that runs the engine, builds the summary and keeps dated reports and logs |
| `setup.ps1` | One-time install check for Python and the libraries |
| `requirements.txt` | Python libraries (Pillow, numpy, PyMuPDF) |
| `power-automate/FaxDuplicateScan_flow.txt` | Power Automate Desktop flow you can paste into PAD |
| `power-automate/BUILD_STEPS.md` | Step-by-step flow build, scheduling and troubleshooting |
| `CLINIC_SORTING_PLAN.md` | **On hold:** sorting faxes into clinic folders, with questions for the team |

---

## Checklist for when you're back at work

### 1. Get the files onto your work PC
Download this repo from GitHub (**Code → Download ZIP**) and copy the `fax-duplicate-finder` folder to
`C:\FaxDedupe`. You can use another location, but then change `ScriptFolder` in the flow to match.

### 2. Install Python and the libraries (one time)
* You need Python 3.9 or newer. Install it from Software Center / Company Portal, or ask IT. Tick **"Add python.exe to PATH"**.
* Then in PowerShell:
  ```
  cd C:\FaxDedupe
  powershell -ExecutionPolicy Bypass -File .\setup.ps1
  ```
  It should end with `Libraries OK` and `Setup complete`.

### 3. Test on a small sample first (important)
1. Make a test folder, e.g. `C:\FaxDedupe\TestFaxes`, and **copy** in 20–50 real faxes.
2. Add a few duplicates you know about: an exact copy of one file, and if you can, a fax that was
   received twice.
3. Run:
   ```
   powershell -ExecutionPolicy Bypass -File .\run_fax_dedupe.ps1 -FaxFolder "C:\FaxDedupe\TestFaxes" -ReportFolder "C:\FaxDedupe\Reports"
   ```
4. Open `C:\FaxDedupe\Reports\fax_duplicates_LATEST.csv` in Excel and check it:
   * Each `group` is one set of duplicates. `KEEP (oldest)` is the file that stays, and the `duplicate` rows are the extra copies.
   * Open a few **`visual`** matches and confirm they really are the same fax.
   * If it groups faxes that are *different*, make it stricter with `-Threshold 0.06`. If it misses
     duplicates you know about, try `-Threshold 0.14`.

### 4. Build the Power Automate Desktop flow
Follow `power-automate/BUILD_STEPS.md`. You can paste the flow in, or build it by hand in about 10 minutes.
Keep `Mode` = `Report` at first.

### 5. Run it on the real share drive (Report mode)
Set `FaxFolder` to the real share and run the flow. You'll get an email with the summary and CSV.
A big share can take a while the first time, roughly a few minutes per 10,000 pages, depending on the network.

### 6. Turn on Move mode (once the team trusts the report)
Set `Mode` = `Move` and set `ReviewFolder` to a folder **outside** the fax folder. Extra copies are moved
there, keeping their subfolder structure. Someone can spot-check them before deleting anything by hand.

---

## Running the engine directly (optional)
```
python find_fax_duplicates.py "\\server\share\Faxes"                  # report only -> fax_duplicates.csv
python find_fax_duplicates.py "Z:\Faxes" --exact-only                 # fastest, identical files only
python find_fax_duplicates.py "Z:\Faxes" --threshold 0.06             # stricter visual match
python find_fax_duplicates.py "Z:\Faxes" --move-duplicates "Z:\Dupes_Review"
```
Files that can't be opened (corrupt or locked) are listed in a separate `...errors.csv`.

## How the visual match works
Each page is converted to grayscale. The top 6% (the fax transmission header with the date, time and
"Page 1 of 3") and the bottom 3% are cropped off. The rest is shrunk to a 16×16 "fingerprint". Two faxes match
when they have the same number of pages and every page's fingerprint is nearly identical.

## Privacy
Everything runs locally on your PC. No fax content is sent to any outside service.
