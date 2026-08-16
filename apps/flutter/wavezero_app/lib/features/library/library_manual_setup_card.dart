import 'package:flutter/material.dart';

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
