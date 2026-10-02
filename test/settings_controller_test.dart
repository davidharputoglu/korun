import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:korun/core/settings/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('user guide startup preference loads and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();

    expect(settings.isLoaded, isFalse);
    await settings.load();
    expect(settings.isLoaded, isTrue);
    expect(settings.showFirstUseGuide, isTrue);

    await settings.setShowFirstUseGuide(false);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('showFirstUseGuide'), isFalse);
  });
}
