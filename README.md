<div align="center">

<img src="docs/images/autoprint-icon.png" width="120" alt="AutoPrint" />

# AutoPrint

**Drop a file in a folder. It gets printed. That's it.**

A lightweight macOS menu bar app that watches folders and automatically
sends PDFs, images, and Office documents to a local printer — no manual
"Open → Print" for every file.

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift)](https://www.swift.org)
[![Release](https://img.shields.io/github/v/release/mengyuefeitian/autoprint?label=release)](../../releases/latest)

</div>

---

## Why

Small offices, classrooms, and home NAS setups often need one thing: files
that land in a folder — scanned documents, exported invoices, homework
synced from a phone — should just come out of the printer, without anyone
sitting at the Mac clicking "Print" one file at a time.

AutoPrint does exactly that and nothing more: it watches folders you
choose, waits for a file to finish arriving, sends it to a printer you've
picked, and keeps a record of what happened.

## Features

- **Folder watching** — one or more folders, each independently enabled or disabled, including folders on mounted network volumes.
- **Broad file support** — PDFs and common image formats print directly; Word/Excel/PowerPoint documents convert to PDF first via headless LibreOffice, Microsoft Word, or Pages (your choice, all off by default).
- **Print quality controls** — color or grayscale, paper size, fit-to-page or actual size.
- **Safe with slow or syncing files** — a file is only sent to the printer once it has stopped changing, so partially written or still-syncing files are never printed half-finished.
- **Automatic retry** — a failed print stays in the watch folder (or is recovered from a legacy failed-folder) and is retried on the next pass; a successful print moves to a `printed` subfolder.
- **Scheduling** — scan on an interval, optionally restricted to a daily time range.
- **Print Now** — force an immediate scan-and-print pass from the menu bar, bypassing the pause toggle and the scheduled time window, for when you don't want to wait.
- **Automatic updates** — checks for new versions once a day in the background (or on demand via **Check for Updates…**), verifies the download's signature, and installs with a click.
- **Logs you can actually read** — an in-app log viewer (copy/clear) plus a log file on disk, for tracing exactly what happened to a given file.
- **Chinese / English UI**, switchable at runtime.
- Runs as a menu bar item only — no Dock icon, no window unless you open Settings.

## What's New

See [CHANGELOG.md](CHANGELOG.md) for the full history. Highlights of the latest release:

**v0.1.27** — Automatic update checks (Sparkle-based, EdDSA-signed, one-click install), a **Print Now** menu item, and a fix for a bug where files could be moved to the "printed" folder before the print job had actually finished if the printer queue was stuck.

## Install

Download the latest `AutoPrint-*.dmg` from [Releases](../../releases/latest), open it, and drag **AutoPrint** into **Applications**.

> The app is ad-hoc signed, not notarized by Apple. On first launch, right-click the app and choose **Open** to get past Gatekeeper's warning.

After the first launch, AutoPrint checks for updates automatically — future versions install with one click from the menu bar.

## Quick Start

1. Launch AutoPrint. It appears as an icon in the menu bar (no Dock icon, no window).
2. Open **Settings** from the menu bar item.
3. Add one or more watch folders.
4. Select a printer.
5. Drop a supported file (PDF, image, or — if you've enabled a conversion method — an Office document) into a watch folder.
6. AutoPrint scans, waits for the file to stabilize, prints it, and moves it into that folder's `printed` subfolder.

Use the menu bar item at any time to pause/resume automatic printing, force an immediate print pass, check for updates, or open the log folder.

## Supported Files

| Type | How it prints |
|---|---|
| PDF | Directly |
| Images (PNG, JPG, TIFF, HEIC, …) | Directly |
| Word / Excel / PowerPoint | Converted to PDF first — enable LibreOffice headless, Microsoft Word, or Pages in Settings (all disabled by default) |

## Current Platform

- **macOS** — available now (macOS 14.0+).
- **Windows** — planned once the macOS workflow is stable.

## Roadmap

| Area | Status |
|---|---|
| Local folder watching, scheduled scan, retry/recovery | ✅ Shipped |
| Office document conversion (LibreOffice / Word / Pages) | ✅ Shipped |
| Print quality settings, scan time windows | ✅ Shipped |
| Automatic updates | ✅ Shipped (v0.1.27) |
| Remote service integration (submit files without a local NAS/sync folder) | 📋 Planned |
| Windows desktop support | 📋 Planned |

## Development

The macOS app lives under `macos/AutoPrintMac` and builds with Swift Package Manager.

```bash
cd macos/AutoPrintMac
./script/build_and_run.sh      # build, sign, and launch a local build
./script/release.sh            # bump the version, build, and package a DMG
```

See `docs/superpowers/` for the design specs and implementation plans behind past features.
