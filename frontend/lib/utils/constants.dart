import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  /// Android emulator uses 10.0.2.2 to reach the host machine's localhost.
  /// iOS simulator / web / desktop can use localhost directly.
  /// A real device needs your computer's LAN IP instead — update this.
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:5000/api';
    } catch (_) {
      // Platform isn't available on some targets; fall through.
    }
    return 'http://localhost:5000/api';
  }

  static const List<String> bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
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
