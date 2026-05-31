enum WaveZeroAppEnv { dev, beta, production }

extension WaveZeroAppEnvLabels on WaveZeroAppEnv {
  String get wireName => switch (this) {
        WaveZeroAppEnv.dev => 'dev',
        WaveZeroAppEnv.beta => 'beta',
        WaveZeroAppEnv.production => 'production',
      };

  String get displayLabel => switch (this) {
        WaveZeroAppEnv.dev => 'Dev',
        WaveZeroAppEnv.beta => 'Beta',
        WaveZeroAppEnv.production => 'Production',
      };
}

class WaveZeroAppConfig {
  const WaveZeroAppConfig({
    required this.appEnv,
    required this.apiBaseUrl,
    required this.contentModeLabel,
    required this.allowManualApiSetup,
    required this.showDeveloperEntry,
    required this.enableDevDiagnosticsByDefault,
    required this.consumerSafeErrorCopy,
    required this.displayVersion,
    required this.buildLabel,
  });

  static const _envDefine = String.fromEnvironment('WAVEZERO_APP_ENV', defaultValue: 'dev');
  static const _apiBaseUrlDefine = String.fromEnvironment('WAVEZERO_API_BASE_URL');
  static const _contentModeDefine = String.fromEnvironment('WAVEZERO_CONTENT_MODE_LABEL');
  static const _devApiBaseUrl = 'http://10.0.2.2:8080';

  static final WaveZeroAppConfig current = WaveZeroAppConfig.fromDartDefines();

  final WaveZeroAppEnv appEnv;
  final String apiBaseUrl;
  final String contentModeLabel;
  final bool allowManualApiSetup;
  final bool showDeveloperEntry;
  final bool enableDevDiagnosticsByDefault;
  final bool consumerSafeErrorCopy;
  final String displayVersion;
  final String buildLabel;

  bool get isDev => appEnv == WaveZeroAppEnv.dev;
  bool get isBeta => appEnv == WaveZeroAppEnv.beta;
  bool get isProduction => appEnv == WaveZeroAppEnv.production;
  String get appEnvLabel => appEnv.displayLabel;

  factory WaveZeroAppConfig.fromDartDefines() {
    final env = _parseEnv(_envDefine);
    final definedBaseUrl = _apiBaseUrlDefine.trim();
    final apiBaseUrl = definedBaseUrl.isNotEmpty
        ? _normalizeBaseUrl(definedBaseUrl)
        : env == WaveZeroAppEnv.dev
            ? _devApiBaseUrl
            : '';
    final contentMode = _contentModeDefine.trim().isNotEmpty
        ? _contentModeDefine.trim()
        : env == WaveZeroAppEnv.dev
            ? 'Local/dev catalog'
            : 'Catalog configured by build';

    return WaveZeroAppConfig(
      appEnv: env,
      apiBaseUrl: apiBaseUrl,
      contentModeLabel: contentMode,
      allowManualApiSetup: env != WaveZeroAppEnv.production,
      showDeveloperEntry: env != WaveZeroAppEnv.production,
      enableDevDiagnosticsByDefault: env == WaveZeroAppEnv.dev,
      consumerSafeErrorCopy: env != WaveZeroAppEnv.dev,
      displayVersion: 'Beta foundation',
      buildLabel: 'Local build',
    );
  }

  static WaveZeroAppEnv _parseEnv(String value) {
    switch (value.trim().toLowerCase()) {
      case 'beta':
        return WaveZeroAppEnv.beta;
      case 'production':
      case 'prod':
        return WaveZeroAppEnv.production;
      case 'dev':
      default:
        return WaveZeroAppEnv.dev;
    }
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) return trimmed.substring(0, trimmed.length - 1);
    return trimmed;
  }
}

class WaveZeroReleaseCopy {
  const WaveZeroReleaseCopy._();

  static const catalogUnavailable = 'Catalog is unavailable right now.';
  static const catalogTryAgain = 'Check your connection or try again later.';
  static const catalogLocalFallback = 'Device music and downloads may still work.';
  static const catalogDeveloperHint = 'Developer Mode can inspect server settings.';
  static const trackUnavailable = 'Track is not available right now.';
  static const playbackCouldNotStart = 'Playback could not start.';
  static const noDownloadsYet = 'No downloads yet.';
  static const downloadsStayOnDevice = 'Downloaded tracks stay on this device.';
  static const deviceMusicPermission = 'Allow access to your device music to import local tracks.';
  static const deviceMusicPrivacy = 'WaveZero does not upload your device music.';
  static const searchLocal = 'Search runs on this device.';
  static const historyLocal = 'Listening history stays on this device.';
}
