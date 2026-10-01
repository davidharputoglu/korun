import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:korun/app.dart';
import 'package:korun/core/app_info.dart';
import 'package:korun/core/settings/settings_controller.dart';
import 'package:korun/features/files/ui/home_page.dart';

void main() {
  testWidgets('Körün app displays the file manager', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsController(),
        child: const KorunApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('v${AppInfo.version}'), findsOneWidget);
  });
}
