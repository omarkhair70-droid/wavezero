from pathlib import Path

app_path = Path('apps/flutter/wavezero_app/lib/app/wavezero_app.dart')
dev_path = Path('apps/flutter/wavezero_app/lib/features/developer/engine_diagnostics_page.dart')
app = app_path.read_text(encoding='utf-8')
dev = dev_path.read_text(encoding='utf-8')

exports = {
    '_StatusStrip': 'WzDeveloperStatusStrip',
    '_MetricsToggle': 'WzDeveloperMetricsToggle',
    '_MetricsPanel': 'WzDeveloperMetricsPanel',
    '_SmartPreloadCard': 'WzSmartPreloadDiagnosticsCard',
    '_SmartDownloadsCard': 'WzSmartDownloadsDiagnosticsCard',
}

for old, new in exports.items():
    if f'class {old} extends StatelessWidget' not in dev:
        raise SystemExit(f'Developer class missing before export: {old}')
    dev = dev.replace(f'class {old} extends StatelessWidget', f'class {new} extends StatelessWidget')
    dev = dev.replace(f'const {old}(', f'const {new}(')
    dev = dev.replace(f'{old}(', f'{new}(')
    app = app.replace(f'{old}(', f'{new}(')

media_import = "import '../../shared/media/media_presentation.dart';\n"
anchor = "import '../../playback/playback_metrics.dart';\n"
if media_import not in dev:
    if anchor not in dev:
        raise SystemExit('Media import anchor missing')
    dev = dev.replace(anchor, anchor + media_import, 1)

for old in exports:
    if f'{old}(' in app or f'class {old} ' in dev or f'{old}(' in dev:
        raise SystemExit(f'Old private diagnostics symbol remains: {old}')
for new in exports.values():
    if f'class {new} extends StatelessWidget' not in dev:
        raise SystemExit(f'Public diagnostics export missing: {new}')

# Analyzer-confirmed stale private token aliases after moving diagnostics.
for line in [
    '  static const Color surfaceElevated = WzColors.surfaceElevated;\n',
    '  static const Color surfaceMuted = WzColors.surfaceMuted;\n',
    '  static const Color borderSoft = WzColors.borderSoft;\n',
    '  static const Color successSoft = WzColors.successSoft;\n',
    '  static const Color warning = WzColors.warning;\n',
    '  static const double space1 = 4;\n',
    '  static const double space2 = 8;\n',
    '  static const double space3 = 12;\n',
    '  static const double space5 = 20;\n',
    '  static const double radiusMd = 18;\n',
    '  static const double radiusLg = 26;\n',
    '  static const TextStyle title = TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3);\n',
    '  static const TextStyle body = TextStyle(color: textMuted, fontSize: 13, height: 1.35);\n',
]:
    if line in app:
        app = app.replace(line, '', 1)

app_path.write_text(app, encoding='utf-8')
dev_path.write_text(dev, encoding='utf-8')
print('Exported reusable developer diagnostics and cleaned stale app tokens')
