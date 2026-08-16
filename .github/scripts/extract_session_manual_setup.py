from pathlib import Path

app_path = Path('apps/flutter/wavezero_app/lib/app/wavezero_app.dart')
dev_path = Path('apps/flutter/wavezero_app/lib/features/developer/engine_diagnostics_page.dart')
manual_path = Path('apps/flutter/wavezero_app/lib/features/library/library_manual_setup_card.dart')
app = app_path.read_text(encoding='utf-8')
dev = dev_path.read_text(encoding='utf-8')


def remove_class(source: str, class_name: str):
    marker = f'class {class_name} extends StatelessWidget {{'
    start = source.find(marker)
    if start < 0:
        raise SystemExit(f'Class marker not found: {class_name}')
    brace = source.find('{', start)
    depth = 0
    end = None
    for i in range(brace, len(source)):
        if source[i] == '{':
            depth += 1
        elif source[i] == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        raise SystemExit(f'Class close not found: {class_name}')
    return source[:start] + source[end:], source[start:end]

app = app.replace('_SessionStrip(', 'WzDeveloperSessionStrip(')
app = app.replace('_TrackSetupCard(', 'WzLibraryManualSetupCard(')

for name in ['_SessionStrip', '_TrackSetupCard', '_Panel']:
    app, _ = remove_class(app, name)

library_import = "import '../features/library/library_manual_setup_card.dart';\n"
anchor = "import '../features/library/library_controls.dart';\n"
if library_import not in app:
    if anchor not in app:
        raise SystemExit('Library import anchor missing')
    app = app.replace(anchor, anchor + library_import, 1)

if '_SessionStrip(' in app or '_TrackSetupCard(' in app or 'class _Panel extends StatelessWidget' in app or '_Panel(' in app:
    raise SystemExit('Legacy session/manual panel symbol remains')
if app.count('WzDeveloperSessionStrip(') != 1:
    raise SystemExit('Expected one developer session strip callsite')
if app.count('WzLibraryManualSetupCard(') != 1:
    raise SystemExit('Expected one manual setup card callsite')

session_widget = r'''

class WzDeveloperSessionStrip extends StatelessWidget {
  const WzDeveloperSessionStrip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: WzSurface.panel(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WzSpacing.md, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.restore, color: WzColors.accent, size: 17),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WzText.caption,
                ),
              ),
            ],
          ),
        ),
      );
}
'''
if 'class WzDeveloperSessionStrip' not in dev:
    dev = dev.rstrip() + session_widget + '\n'

manual = r'''import 'package:flutter/material.dart';

import '../../design/wavezero_design_system.dart';

class WzLibraryManualSetupCard extends StatelessWidget {
  const WzLibraryManualSetupCard({
    super.key,
    required this.titleController,
    required this.urlController,
    required this.apiBaseUrlController,
    required this.catalogStatus,
    required this.loading,
    required this.onLoadCatalog,
    required this.onLoadTrack,
  });

  final TextEditingController titleController;
  final TextEditingController urlController;
  final TextEditingController apiBaseUrlController;
  final String catalogStatus;
  final bool loading;
  final VoidCallback onLoadCatalog;
  final VoidCallback onLoadTrack;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: WzSurface.panel(),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Manual / API setup'),
            subtitle: Text(catalogStatus, maxLines: 2, overflow: TextOverflow.ellipsis),
            children: [
              TextField(controller: apiBaseUrlController, decoration: const InputDecoration(labelText: 'API base URL')),
              const SizedBox(height: 12),
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Manual title')),
              const SizedBox(height: 12),
              TextField(controller: urlController, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Manual audio URL')),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: loading ? null : onLoadCatalog,
                    icon: loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_download),
                    label: const Text('Reload selected/API'),
                  ),
                  OutlinedButton.icon(
                    onPressed: loading ? null : onLoadTrack,
                    icon: const Icon(Icons.bolt),
                    label: const Text('Load manual track'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
'''

app_path.write_text(app, encoding='utf-8')
dev_path.write_text(dev, encoding='utf-8')
manual_path.write_text(manual, encoding='utf-8')
print('Extracted developer session strip and Library manual setup; removed legacy _Panel')
