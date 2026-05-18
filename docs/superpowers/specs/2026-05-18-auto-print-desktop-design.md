# Auto Print Desktop Design

## Goal

Build two native desktop applications, one for macOS and one for Windows, that run in the background, scan user-configured folders on a schedule, print supported files through a selected local printer, move completed files into a printed folder, and record durable print history.

## Product Scope

The first version is for single-user local use. It does not include cloud synchronization, remote management, multi-user access control, or advanced per-document print templates.

The applications must support:

- macOS menu bar app.
- Windows system tray app.
- One or more user-configured watch folders.
- One selected default local printer.
- Printer availability detection.
- Scheduled scanning, defaulting to every 30 seconds.
- File stability checks before printing, defaulting to 10 seconds.
- Print ordering by file creation time from oldest to newest.
- PDF, common image formats, Word, Excel, and PowerPoint files.
- Local printing through system capabilities or installed applications.
- Moving successful files to a `printed` subfolder.
- Moving failed files to a `failed` subfolder.
- Three retry attempts by default.
- Local print history with completion time and file name.

## Architecture

The project will use two native codebases with consistent behavior and data formats.

The macOS app will use SwiftUI for windows and AppKit for menu bar and platform printing integration. The Windows app will use .NET 8 with WPF, Windows printing APIs, Office automation, shell printing, and LibreOffice command-line fallback.

The implementations are separate, but the configuration schema, log fields, queue states, retry rules, and file handling rules must remain aligned across platforms. This keeps the first version practical while avoiding the compatibility risk of forcing all printing behavior through a shared cross-platform core.

## Runtime Behavior

Each app runs as a background application after launch.

The tray or menu bar controls must include:

- Start or pause automatic printing.
- Open settings.
- Open logs.
- Open print capability detection.
- Quit.

The app scans configured folders only when automatic printing is enabled. It must skip hidden files, temporary files, folders, and files inside the configured `printed` or `failed` subfolders.

## File Discovery And Queueing

When the scanner discovers a file, it records the file path, size, modified time, creation time, and discovery time.

A file is eligible for printing only after its size and modified time remain unchanged for the configured stability window. The default stability window is 10 seconds.

Eligible files are sorted by:

1. Creation time, oldest first.
2. Natural file name order when creation times are equal.

The app processes one print task at a time per selected printer. It must not flood the operating system print queue with all discovered files at once.

Queue states:

- `Pending`: discovered but not yet checked for stability.
- `Stabilizing`: waiting for stable size and modified time.
- `Queued`: stable and waiting to print.
- `Printing`: print submission is in progress.
- `Submitted`: print command was accepted by the local print path.
- `Printed`: file was submitted, moved to the printed folder, and logged.
- `Retrying`: print submission failed and will be retried.
- `Failed`: retry limit was reached or the file cannot be printed.

For the first version, "printed" means the file was successfully submitted to the local operating system or application print path and the app completed its post-processing. The app does not promise reliable physical page-output confirmation, because printer drivers and document applications expose that state inconsistently.

## Successful Print Handling

After a task is submitted successfully:

1. Mark the task as `Submitted`.
2. Move the original file into the configured printed subfolder.
3. If a file with the same name already exists there, append a timestamp to the moved file name.
4. Mark the task as `Printed`.
5. Write a success record to the SQLite log.

The default printed subfolder name is `printed`.

## Failed Print Handling

A print attempt fails when:

- The selected printer is missing, paused, offline, or in an error state.
- The document format is unsupported on that machine.
- The required local application cannot be found.
- The document application returns an error.
- The print command times out.
- The file cannot be opened, read, or moved.

Failed attempts are retried up to the configured retry limit. The default retry limit is 3.

After the retry limit is reached:

1. Move the file into the configured failed subfolder.
2. If a file with the same name already exists there, append a timestamp to the moved file name.
3. Mark the task as `Failed`.
4. Write a failure record to the SQLite log with the final error message and retry count.

The default failed subfolder name is `failed`.

## macOS Printing Design

The macOS app must enumerate local printers through system printing APIs or CUPS.

Printer availability detection must confirm:

- The configured printer exists.
- The printer is not paused when that state is available.
- The app can submit jobs to the system print path.

Format handling:

- PDF: use system printing capabilities or `lp`/`lpr` where reliable.
- Images: print through a controlled image-to-print path, with scaling, centering, and orientation handling. Converting images to a temporary PDF is acceptable if it improves consistency.
- Word, Excel, PowerPoint: use installed Microsoft Office or LibreOffice to submit the document for printing. If no suitable application is available, fail the task with a dependency error.

The menu bar integration must use `NSStatusItem`.

## Windows Printing Design

The Windows app must enumerate local printers through Windows printing APIs or .NET printing services.

Printer availability detection must confirm:

- The configured printer exists.
- The printer is not offline when that state is available.
- The printer is not reporting a blocking error when that state is available.

Format handling:

- PDF: use a configured or detected PDF application that supports command-line printing when possible. Adobe Reader, SumatraPDF, or another stable local PDF print path can be used. Shell printing is acceptable as a fallback.
- Images: print with .NET `PrintDocument` or another controlled native image printing path, with scaling, centering, and orientation handling.
- Word, Excel, PowerPoint: use Microsoft Office COM automation when Office is installed. If Office is unavailable, try LibreOffice command-line printing. If neither path is available, fail the task with a dependency error.

The Windows tray integration must expose the same user actions as the macOS menu bar app.

## Print Capability Detection

Both apps must provide a capability detection view showing:

- Selected printer availability.
- PDF print support.
- Image print support.
- Word print support.
- Excel print support.
- PowerPoint print support.

Each capability is shown as available or unavailable, with a short reason when unavailable.

## Configuration

Configuration is stored locally as JSON. Both platforms use the same field names.

Example:

```json
{
  "watchFolders": [
    {
      "path": "/Users/example/PrintInbox",
      "enabled": true
    }
  ],
  "printerName": "Office Printer",
  "scanIntervalSeconds": 30,
  "fileStableSeconds": 10,
  "maxRetries": 3,
  "printedFolderName": "printed",
  "failedFolderName": "failed",
  "launchAtLogin": true,
  "autoPrintEnabled": true
}
```

The settings UI must allow users to:

- Add, remove, enable, and disable watch folders.
- Select the default printer.
- Change scan interval.
- Change file stability wait time.
- Change retry count.
- Change printed and failed folder names.
- Enable or disable launch at login.
- Pause or resume automatic printing.

## Logging

The apps store logs in local SQLite databases.

Log fields:

- `id`
- `file_name`
- `original_path`
- `final_path`
- `printer_name`
- `file_type`
- `status`
- `discovered_at`
- `submitted_at`
- `completed_at`
- `retry_count`
- `error_message`

The UI must show logs with status filtering for successful and failed jobs.

## User Interface

The first version contains four primary views:

- Status: current running state, selected printer, queued file count, current task, and last scan time.
- Settings: watch folders, printer selection, scan interval, stability wait time, retry count, folder names, launch at login, and automatic printing.
- Logs: recent print records with status filtering.
- Capability detection: printer and format support checks.

The UI should be operational and compact rather than marketing-oriented. It should prioritize repeat use, fast status checks, and clear failure explanations.

## Restart And Recovery

On application startup, the app must:

1. Load configuration.
2. Open the SQLite log database.
3. Recover incomplete tasks from the persisted SQLite task table.
4. Re-scan watch folders.
5. Avoid reprinting files already moved to the printed folder.

If the app crashes while a file is still in the watch folder and was not moved to `printed`, the app may discover it again and retry. If the file was already moved to `printed`, it must not be printed again.

## Edge Cases

The apps must handle:

- Files still being copied.
- Duplicate file names in printed and failed folders.
- Missing, offline, paused, or errored printers.
- Unsupported file extensions.
- Installed document applications that display blocking dialogs.
- Print command timeouts.
- Watch folders that are deleted, renamed, or temporarily unavailable.
- File permission errors.
- Application upgrades that preserve configuration and logs.

## Testing Strategy

Core logic tests:

- Queue sorting by creation time.
- Natural file name tie-break ordering.
- File stability detection.
- Exclusion of printed and failed folders.
- Retry behavior and final failure movement.
- Successful movement into printed folder.
- Duplicate destination filename handling.
- Log record creation for success and failure.

Platform integration tests:

- Printer enumeration.
- Selected printer availability detection.
- PDF printing through the configured path.
- Image printing through the controlled native path.
- Word, Excel, and PowerPoint printing through Office or LibreOffice.
- Behavior when dependencies are missing.
- Behavior when the printer is unavailable.

Manual acceptance tests:

- Configure a watch folder and printer.
- Place PDF, image, Word, Excel, and PowerPoint files into the folder.
- Confirm files print in creation-time order.
- Confirm successful files move to `printed`.
- Confirm failed files retry 3 times and move to `failed`.
- Confirm logs include file name, printer, status, completion time, and error message when relevant.
- Confirm pause and resume work from the tray or menu bar.
- Confirm launch at login starts the app in the background.

## Non-Goals For Version One

The first version will not include:

- Cloud queue management.
- Remote administration.
- Multi-user permissions.
- Per-folder printer mapping.
- Per-file print setting templates.
- Guaranteed physical page-output confirmation.
- OCR or document content inspection.
- Network service deployment.

These can be added later after the local single-user print workflow is stable.
