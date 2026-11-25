# Sorting faxes by clinic: ON HOLD

**Status:** waiting on a team decision. Nothing here is built yet.

The idea: after duplicates are removed, file each fax into a folder per clinic, for example
`\\SERVER\Share\Faxes\<Clinic Name>\<Year>\<Month>\`.

## Questions for the team
1. **How do we tell which clinic a fax belongs to?** Pick whichever is most reliable:
   - [ ] The fax number it was **sent to** (each clinic has its own line). This is the easiest and most reliable, if our fax system includes it in the file name or metadata
   - [ ] The fax number it came **from** (e.g. referring offices)
   - [ ] Text on the **cover sheet** (clinic name/address). Needs OCR or AI Builder
   - [ ] It's already in the **file name** or the folder it lands in
2. **What's the full list of clinics** and their fax numbers / names as they appear on faxes?
3. **What should happen to faxes we can't match?** (Suggestion: an `_Unsorted` folder plus a daily email.)
4. **Folder layout?** Just by clinic, or clinic → year → month?
5. **Who has to approve** before files are moved automatically? Do we need a "report only" trial period first?
6. **Retention / compliance:** are there rules (HIPAA, records retention) about moving faxes, or about who can see which clinic's folder?
7. **Does the fax system / EHR already route these?** If so, sorting on the share drive might not be needed.

## How it would plug in (once decided)
- **Clinic comes from the fax line / file name / metadata:** add a `clinics.csv` lookup
  (`fax_number,clinic_name`) and a sort step in `run_fax_dedupe.ps1`. No AI needed and no extra cost.
- **Clinic only appears on the cover sheet:** add OCR to the Python script (Tesseract, free, runs locally)
  or an AI Builder text recognition / document processing step in Power Automate
  (licensed and billed per page; check that faxes with patient information are allowed to go to that service).

Bring the answers back and the sort step can be built on top of what's already here.
