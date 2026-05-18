# Acceptance Fixtures

Use a real or virtual local printer for manual acceptance.

Prepare these files in a clean watch folder:

- 001-oldest.pdf
- 002-image.png
- 003-word.docx
- 004-excel.xlsx
- 005-powerpoint.pptx

Set their creation times in ascending order. Start automatic printing and confirm:

- Files are submitted oldest first.
- Successful files move to `printed`.
- Failed files retry three times and move to `failed`.
- Logs include file name, original path, final path, printer name, status, completion time, retry count, and error message when relevant.
