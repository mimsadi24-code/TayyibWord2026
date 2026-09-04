# Tayyib Word — Rich Text Engine (v8)

This build replaces the single-style TextField document surface with Flutter Quill 11.5.1, a WYSIWYG rich-text editor.

Implemented in this build:
- true per-selection bold / italic / underline / strike-through
- font family and font size controls
- text and highlight color controls
- paragraph alignment
- bullet and numbered lists
- indent controls
- headings and clear-format
- links
- undo / redo inside the rich editor
- subscript / superscript controls
- rich document selection/copy/cut and cursor-aware insertion
- legacy .twd text/layout data remains mirrored for existing document features

Note: the existing page-layout, DOCX and object systems are still separate subsystems and are not magically converted into a full Microsoft Word rendering engine by this change.
