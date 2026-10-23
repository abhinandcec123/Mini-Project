import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepulse_ai/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates the existing token before logout clears secure credentials',
      () async {
    SharedPreferences.setMockInitialValues({
      'lp_token': 'legacy-session-token',
      'lp_role': 'donor',
      'lp_password_change_required': false,
    });
    FlutterSecureStorage.setMockInitialValues({});

    final auth = AuthProvider();
    for (var attempt = 0; attempt < 20 && auth.isRestoring; attempt++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(auth.isRestoring, isFalse);
    expect(auth.token, 'legacy-session-token');
    expect(auth.role, 'donor');

    const storage = FlutterSecureStorage();
    expect(await storage.read(key: 'lp_token'), 'legacy-session-token');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('lp_token'), isNull);

    await auth.logout();
    expect(await storage.read(key: 'lp_token'), isNull);
    expect(preferences.getString('lp_role'), isNull);
    auth.dispose();
  });
}
