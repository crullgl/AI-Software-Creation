# Building the "Fax Duplicate Scan" flow in Power Automate Desktop

The flow is small on purpose. The scanning, summary and file moves all happen in
`run_fax_dedupe.ps1`. Power Automate Desktop (PAD) runs that script and emails the result.

```
[Set 7 settings] -> [Run PowerShell script] -> [Launch Outlook]
      -> did the script return an error?
           yes -> email "FAILED" + error text
           no  -> email summary + attach fax_duplicates_LATEST.csv
      -> [Close Outlook]
```

## Option A: paste it (fastest)
1. In PAD, click **+ New flow** and name it `Fax Duplicate Scan`.
2. Open `FaxDuplicateScan_flow.txt`, copy everything below the `----- COPY BELOW -----` line,
   click in the empty **Main** area of the flow and press **Ctrl+V**.
3. Double-click each of the 7 **Set variable** actions at the top and enter your values (table below).
4. Click **Save**, then **Run**.

If the paste does nothing, or an action shows a red error, PAD's paste format may differ in
your version. Delete the pasted actions and use Option B.

## Option B: build it by hand (about 10 minutes)

### 1. Variables: 7 × **Variables → Set variable**
| Variable | Example value | Notes |
|---|---|---|
| `FaxFolder` | `\\SERVER\Share\Faxes` | The share drive folder to scan (subfolders included) |
| `ScriptFolder` | `C:\FaxDedupe` | Where you copied this repo's `fax-duplicate-finder` files |
| `ReportFolder` | `C:\FaxDedupe\Reports` | CSV reports and logs go here |
| `ReviewFolder` | `\\SERVER\Share\Fax_Duplicates_Review` | Must be **outside** `FaxFolder`. Used only in Move mode |
| `Mode` | `Report` | `Report` = only list duplicates. `Move` = also move the extra copies |
| `EmailFrom` | your Outlook address | The account in Outlook to send from |
| `EmailTo` | your team's address | Separate several addresses with `;` |

### 2. **Scripting → Run PowerShell script**
* Script to run (type it exactly, including the double quotes):
  ```
  & "%ScriptFolder%\run_fax_dedupe.ps1" -FaxFolder "%FaxFolder%" -ReportFolder "%ReportFolder%" -Mode %Mode% -ReviewFolder "%ReviewFolder%"
  ```
* Variables produced: keep the defaults `PowershellOutput` and `ScriptError`.

### 3. **Outlook → Launch Outlook**
* Variable produced: `OutlookInstance`

### 4. **Conditionals → If**: `%ScriptError%` **is not empty**
* Inside the If: **Outlook → Send email message through Outlook**
  * Account: `%EmailFrom%`, To: `%EmailTo%`
  * Subject: `Fax duplicate scan FAILED`
  * Body: `%ScriptError%`
* Add **Conditionals → Else**, and inside it another **Send email message through Outlook**:
  * Account: `%EmailFrom%`, To: `%EmailTo%`
  * Subject: `Fax duplicate scan results`
  * Body: `%PowershellOutput%`
  * Attachment(s): `%ReportFolder%\fax_duplicates_LATEST.csv`

### 5. **Outlook → Close Outlook**
* Outlook instance: `%OutlookInstance%`

## What the email looks like
```
Fax duplicate scan - 2026-12-01 07:30
Folder scanned : \\SERVER\Share\Faxes
Mode           : Report

Duplicate groups      : 42
Extra copies found    : 57  (exact: 31, visual: 26)
Space used by copies  : 118.4 MB
Unreadable files      : 2

Report: C:\FaxDedupe\Reports\fax_duplicates_2026-12-01_0730.csv
Nothing was moved. Review the report, then run in Move mode.
```

## Running it on a schedule
PAD on its own can't run a flow on a timer. Your options:
1. **Cloud flow (needs a Premium license):** in Power Automate online, create a *Scheduled cloud flow*
   with a **Recurrence** trigger, then the **Run a flow built with Power Automate for desktop** action
   pointing at this flow. The PC has to be registered as a machine (or gateway).
2. **Windows Task Scheduler without PAD:** run the PowerShell script directly. Use program `powershell.exe` with arguments
   `-ExecutionPolicy Bypass -File "C:\FaxDedupe\run_fax_dedupe.ps1" -FaxFolder "\\SERVER\Share\Faxes" -ReportFolder "C:\FaxDedupe\Reports"`.
   You still get the reports, but no email.
3. **Run it by hand:** click Run in PAD whenever you want a scan.

## Troubleshooting
| Symptom | Fix |
|---|---|
| Email says `python` is not recognized | Run `setup.ps1`. If Python is installed but not on PATH, add `-Python "C:\Path\To\python.exe"` to the end of the script line in step 2 |
| "running scripts is disabled on this system" | Change the step 2 line to start with `powershell -ExecutionPolicy Bypass -File "%ScriptFolder%\run_fax_dedupe.ps1"`, then the same arguments, and drop the leading `&` |
| "Fax folder not found" | The account PAD runs as can't reach the share. Open the path in File Explorer as that user |
| "ReviewFolder must be OUTSIDE the fax folder" | Pick a review folder that isn't inside the folder being scanned |
| Outlook action fails | Open Outlook once by hand and sign in. `EmailFrom` must match an account in Outlook exactly |
