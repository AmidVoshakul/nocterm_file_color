## 0.0.1

- Initial release of nocterm_file_color
- `FileTextField` wrapper over Nocterm TextField with colored inline file tags
- `FileTag` component for clickable colored file labels
- `FileConfig` for per-type styling (image, document, code, archive, audio, video, other)
- `FileDetector` for extension-to-type mapping
- `FileInfo` model with path, name, extension, type, size
- `FileOpener` for cross-platform file location opening (xdg-open / open / explorer)
- Paste interception via `TextField.onPaste`
- Key event interception via `TextField.onKeyEvent` (@, Ctrl+V)
- `getAttachedFiles()` method for retrieving current attachments
- `onFilesChanged` callback for attachment list changes
- `onFileClick` callback for tag tap handling