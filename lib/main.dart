import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/settings/settings_controller.dart';
import 'features/otken/otken_daemon.dart';

void main(List<String> args) async {
  if (args.contains('--otken-daemon')) {
    await runOtkenDaemon(await loadOtkenConfig());
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsController()..load(),
      child: const KorunApp(),
    ),
  );
}
