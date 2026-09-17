# Changelog

All notable changes to AutoPrint are documented here. Dates are in `YYYY-MM-DD`, newest first.

## 0.1.27 - 2026-09-17

### Added
- **Automatic update checks**, built on [Sparkle](https://sparkle-project.org/). AutoPrint checks for a new version once a day in the background, or on demand from **Check for Updates…** in the menu bar. Downloads are verified with an EdDSA signature before installing, then the app relaunches on the new version automatically — no more manually downloading a DMG and dragging it into Applications.
- **Print Now** menu item: forces an immediate scan-and-print pass over the watch folders, bypassing both the "pause printing" toggle and the configured scan time window (still waits for files to finish being written before printing them). For the rare case where you don't want to wait for the next scheduled scan.
- Sparkle's own update dialogs (checking for updates, error messages, install prompts) now follow AutoPrint's Chinese/English language setting instead of always showing in English, by routing their string lookups through the correct bundled localization.

### Fixed
- **Files were being moved to the "printed" folder before the print job actually finished.** `lp` reports success as soon as a job is accepted into the CUPS queue — not once it has actually printed. If the print queue was stuck, blocked, or the printer was offline, the source file was already gone from the watch folder even though nothing had printed. AutoPrint now polls the CUPS queue and only treats a job as done once it has actually left the queue; a stuck job is treated as a failure and retried like any other print error.
- The scan log no longer repeats "outside configured scan time range" on every tick while outside the scheduled scan window — it now logs only when entering or leaving that window.
- Fixed a packaging regression where a freshly updated local Swift toolchain could silently produce a build that required a macOS version newer than any real release, so nobody (including the machine that built it) could open the app. Builds now explicitly pin the deployment target and verify it before shipping.
- Fixed the DMG packaging script leaking its own progress output into the value the release script reports as the built DMG's path.

## 0.1.1 - 0.1.26 - 2026-05-18 to 2026-09-16

The initial development series. Individual builds in this range were not tagged as GitHub releases; this entry summarizes the functionality that shipped across them.

### Added
- Menu bar app (no Dock icon) that scans one or more configurable watch folders on a schedule and prints matching files to a selected system printer.
- PDF and common image formats print directly; Office documents (`doc`/`docx`/`xls`/`xlsx`/`ppt`/`pptx`) convert to PDF first via a configurable method — headless LibreOffice, Microsoft Word, or Pages — before printing.
- Print quality settings: color/grayscale, paper size, fit-to-page vs. actual size.
- File-stability check so a file is only printed once it has finished being written or copied into the watch folder (important for files arriving over a network share or slow sync).
- Successful prints move to a `printed` subfolder; failed prints stay in place and are retried automatically, including recovering files from a legacy `failed` folder.
- Optional daily scan time range, so AutoPrint only scans during configured hours.
- Support for watch folders on mounted network volumes, with more detailed logging for diagnosing network-storage issues.
- In-app log viewer with copy/clear, plus a persisted log file on disk.
- Chinese/English UI language toggle.
- Local, unsigned DMG packaging via `script/build_and_run.sh` and `script/package_dmg.sh`.

---

Full commit history: [github.com/mengyuefeitian/autoprint/commits](https://github.com/mengyuefeitian/autoprint/commits/main/).
