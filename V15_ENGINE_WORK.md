# Tayyib Word v15 — Layout Engine Pass

- Replaced character-count pagination with word-aware line wrapping.
- Added page line capacity and printable-width calculations based on paper size, orientation and margins.
- Preserves explicit page-break markers.
- Honors page-break-before and keep-with-next settings during pagination.
- Preserves blank paragraphs in page flow.
- Status bar now derives total page count from the layout engine instead of counting only explicit page-break markers.
- Existing v14 table, image, shape, DOCX/PDF, notes, comments and review features remain intact.

Limitation: Flutter Quill remains the interactive editor surface; this pass improves the document pagination model/preview but is not a complete Word-compatible layout compositor or native OOXML round-trip engine.
