# AutoPrint

AutoPrint is a desktop app for automatic local printing. It is designed for a simple workflow: users place files into a fixed folder, and the app periodically scans that folder, sends supported files to a configured system printer, and records the print result.

## Use Case

Many small offices, classrooms, and home NAS workflows need a lightweight way to print files without manually opening each document. AutoPrint fits this scenario:

1. Choose one or more local watch folders.
2. Put files into those folders, including files synced from a NAS or other local storage.
3. AutoPrint scans the folders on a schedule.
4. Files are printed through a selected system printer.
5. Completed print jobs are recorded with the file name and completion time.

At the current stage, remote file storage depends on the user's own NAS or local sync solution. A future version of the app is planned to integrate with a remote service directly.

## Current Platform

- macOS app is available.
- Windows support is planned after the macOS workflow is stable.

## Supported Files

AutoPrint is intended to handle common printable files such as:

- PDF files
- Images
- Office documents, when an Office conversion method is enabled in settings

Office document printing can be configured to use LibreOffice headless conversion, Microsoft Word, or Pages on macOS. These options are disabled by default so users can choose the method that matches their local environment.

## Printing Workflow

- The user selects watch folders.
- The user selects an available local printer.
- The app periodically scans configured folders.
- Files are processed in order.
- Successfully printed files are moved to the printed folder.
- Failed files remain available for retry.
- Logs record scan, print, success, and failure details.

## Roadmap

- Continue improving macOS printing reliability.
- Add remote service integration for receiving and managing files.
- Add Windows desktop support.

