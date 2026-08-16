import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/app/app_config.dart';
import 'package:wavezero_app/features/library/library_status_presentation.dart';

void main() {
  test('catalog mode labels preserve demo, production, and count fallback', () {
    expect(wzCatalogModeLabel('demo', 0), 'Demo catalog');
    expect(wzCatalogModeLabel('prod', 0), 'Catalog ready');
    expect(wzCatalogModeLabel(null, 2), 'Catalog ready');
    expect(wzCatalogModeLabel(null, 0), 'Catalog unavailable');
  });

  test('friendly load errors preserve permission/network/generic copy', () {
    expect(
      friendlyWzLoadError('permission denied'),
      WaveZeroReleaseCopy.deviceMusicPermission,
    );
    expect(
      friendlyWzLoadError('SocketException: connection failed'),
      '${WaveZeroReleaseCopy.catalogUnavailable} ${WaveZeroReleaseCopy.catalogTryAgain}',
    );
    expect(
      friendlyWzLoadError('decoder failed'),
      WaveZeroReleaseCopy.playbackCouldNotStart,
    );
  });

  test('consumer catalog status keeps exact ready/fallback semantics', () {
    expect(wzConsumerCatalogStatus('Demo catalog loaded'), 'Demo catalog');
    expect(wzConsumerCatalogStatus('Catalog ready with 20 tracks'), 'Catalog ready');
    expect(
      wzConsumerCatalogStatus('Catalog unavailable: connection error'),
      '${WaveZeroReleaseCopy.catalogUnavailable} ${WaveZeroReleaseCopy.catalogTryAgain} ${WaveZeroReleaseCopy.catalogLocalFallback}',
    );
    expect(
      wzConsumerCatalogStatus('Imported 5 device tracks'),
      'Imported 5 device tracks',
    );
    expect(
      wzConsumerCatalogStatus('idle'),
      'Choose music from your library.',
    );
  });

  test('consumer device error is nullable and delegates to friendly copy', () {
    expect(wzConsumerDeviceError(null), isNull);
    expect(wzConsumerDeviceError(''), isNull);
    expect(
      wzConsumerDeviceError('permission rejected'),
      WaveZeroReleaseCopy.deviceMusicPermission,
    );
  });
}
