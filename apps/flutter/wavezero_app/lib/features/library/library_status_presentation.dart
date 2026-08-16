import '../../app/app_config.dart';

String wzCatalogModeLabel(String? contentMode, int trackCount) {
  final normalized = contentMode?.trim().toLowerCase().replaceAll('-', '_');
  if (normalized == 'demo' ||
      normalized == 'demo_catalog' ||
      normalized == 'legal_demo') {
    return 'Demo catalog';
  }
  if (normalized == 'production' ||
      normalized == 'prod' ||
      normalized == 'catalog_ready') {
    return 'Catalog ready';
  }
  if (trackCount > 0) return 'Catalog ready';
  return 'Catalog unavailable';
}

String friendlyWzLoadError(String error) {
  final normalized = error.toLowerCase();
  if (normalized.contains('permission')) {
    return WaveZeroReleaseCopy.deviceMusicPermission;
  }
  if (normalized.contains('socketexception') ||
      normalized.contains('connection') ||
      normalized.contains('http')) {
    return '${WaveZeroReleaseCopy.catalogUnavailable} ${WaveZeroReleaseCopy.catalogTryAgain}';
  }
  return WaveZeroReleaseCopy.playbackCouldNotStart;
}

String wzConsumerCatalogStatus(String status) {
  final normalized = status.toLowerCase();

  if (normalized.contains('demo catalog')) return 'Demo catalog';
  if (normalized.contains('catalog ready')) return 'Catalog ready';
  if (normalized.contains('catalog unavailable') ||
      normalized.contains('unavailable') ||
      normalized.contains('error') ||
      normalized.contains('exception') ||
      normalized.contains('failed')) {
    return '${WaveZeroReleaseCopy.catalogUnavailable} ${WaveZeroReleaseCopy.catalogTryAgain} ${WaveZeroReleaseCopy.catalogLocalFallback}';
  }
  if (normalized.contains('permission')) {
    return WaveZeroReleaseCopy.deviceMusicPermission;
  }
  if (normalized.contains('loaded') || normalized.contains('imported')) {
    return status;
  }
  if (normalized.contains('offline')) return status;
  return 'Choose music from your library.';
}

String? wzConsumerDeviceError(String? error) {
  if (error == null || error.isEmpty) return null;
  return friendlyWzLoadError(error);
}
