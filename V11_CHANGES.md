# Tayyib Word v11 changes

- Upgraded PDF export to use the selected page size/orientation and document margins.
- PDF now uses real MultiPage pagination and carries header/footer plus automatic PDF page numbers.
- PDF export respects explicit page-break markers.
- Added basic PDF column layout for 2+ columns.
- Fixed DOCX header/footer relationship wiring (`word/_rels/document.xml.rels`).
- Added DOCX content-type overrides for header/footer parts.
- DOCX section properties now include header/footer references, page size, margins and columns.
- Preserved Quill Delta rich-text export and `.twd` Delta persistence from v10.
- No Flutter SDK is available in this container, so APK compilation is not claimed as verified.
