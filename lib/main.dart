import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'providers/transfer_provider.dart';
import 'app.dart';
import 'services/tray_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Detect --hidden argument from command line
  if (Platform.isWindows) {
    appStartHidden = Platform.executableArguments.contains('--hidden');
    if (!appStartHidden) {
      // Fallback: scan raw args for safety
      for (final arg in Platform.executableArguments) {
        if (arg == '--hidden') {
          appStartHidden = true;
          break;
        }
      }
    }
  }

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(420, 760),
      minimumSize: Size(420, 760),
      title: 'ZenTransfer',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (appStartHidden) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    });

    // Initialize tray service
    final trayService = TrayService(
      onShow: () async {
        await windowManager.show();
        await windowManager.focus();
      },
      onQuit: () async {
        await trayManager.destroy();
        exit(0);
      },
    );
    await trayService.init();
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => TransferProvider(),
      child: const ZenTransferApp(),
    ),
  );
}
