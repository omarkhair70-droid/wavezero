from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()

start_marker = "  // Predictive Smart Downloads helpers\n) async {\n"
end_marker = "  void _recordSmartDownloadSkip(String reason) {\n"
start = text.find(start_marker)
end = text.find(end_marker, start)
if start < 0 or end < 0:
    raise SystemExit('stale Smart Downloads helper block not found')
text = text[:start] + "  // Predictive Smart Downloads helpers\n" + text[end:]
path.write_text(text)
