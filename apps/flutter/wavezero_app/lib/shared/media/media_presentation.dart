String wzProductQualityLabel(String? value) {
  final normalized = value?.trim().toLowerCase();
  switch (normalized) {
    case 'original':
    case 'lossless':
      return 'Original';
    case 'high':
      return 'High';
    case 'standard':
    case 'low':
      return 'Standard';
    case null:
    case '':
    case 'unknown':
      return 'Unknown';
    default:
      return value!;
  }
}

String wzCachedSourceBadgeLabel(String? displayName) {
  final source = displayName?.split(' ').first ?? 'unknown';
  switch (source) {
    case 'manual':
      return 'Manual';
    case 'smart_current':
      return 'Smart Current';
    case 'smart_up_next':
      return 'Smart Up Next';
    default:
      return 'Unknown';
  }
}
