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
