import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, kReleaseMode;

class AppConstants {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _configuredEnvironment = String.fromEnvironment('APP_ENV');
  static const _allowInsecureHttp =
      bool.fromEnvironment('ALLOW_INSECURE_HTTP', defaultValue: false);

  static bool get isProduction =>
      kReleaseMode || _configuredEnvironment == 'production';

  /// A release must be given an HTTPS API URL. Local HTTP is limited to
  /// explicitly enabled development builds and private/local network hosts.
  static String get baseUrl {
    var configured = _configuredBaseUrl.trim();
    if (configured.isEmpty) {
      if (isProduction) {
        throw StateError(
          'Production API configuration is missing. Build with '
          '--dart-define=API_BASE_URL=https://your-api-host/api.',
        );
      }
      if (kIsWeb) {
        configured = 'http://localhost:5000/api';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        configured = 'http://10.0.2.2:5000/api';
      } else {
        configured = 'http://localhost:5000/api';
      }
    }

    final uri = Uri.tryParse(configured);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.host.isEmpty ||
        uri.path.isEmpty) {
      throw StateError('API_BASE_URL must be an absolute URL including /api.');
    }
    if (uri.scheme == 'https') {
      return configured.replaceFirst(RegExp(r'/+$'), '');
    }
    if (uri.scheme != 'http' ||
        isProduction ||
        !_allowInsecureHttp ||
        !_isPrivateHost(uri.host)) {
      throw StateError(
        'HTTP API URLs are allowed only for explicitly enabled local development. '
        'Use HTTPS for production.',
      );
    }
    return configured.replaceFirst(RegExp(r'/+$'), '');
  }

  static bool _isPrivateHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized == 'localhost' ||
        normalized == '::1' ||
        normalized == '10.0.2.2') {
      return true;
    }
    final octets = normalized.split('.');
    if (octets.length != 4) return false;
    final values = octets.map(int.tryParse).toList();
    if (values.any((value) => value == null || value < 0 || value > 255)) {
      return false;
    }
    final first = values[0]!;
    final second = values[1]!;
    return first == 10 ||
        first == 127 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }

  static const List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  static const List<String> priorities = [
    'critical',
    'urgent',
    'medium',
    'normal',
  ];

  static const primaryRed = 0xFFD32F2F;
  static const darkRed = 0xFFB71C1C;
}
