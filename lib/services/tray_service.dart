import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener, WindowListener {
  final VoidCallback? onShow;
  final VoidCallback? onQuit;

  TrayService({this.onShow, this.onQuit});

  Future<void> init() async {
    trayManager.addListener(this);
    windowManager.addListener(this);

    await trayManager.setIcon(
      Platform.isWindows
          ? 'assets/icons/icon_96.png'
          : 'assets/icons/icon_96.png',
    );

    final menu = Menu(
      items: [
        MenuItem(
          key: 'show_window',
          label: 'Show',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit_app',
          label: 'Quit',
        ),
      ],
    );

    await trayManager.setContextMenu(menu);
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideWindow() async {
    await windowManager.hide();
  }

  Future<void> quit() async {
    await trayManager.destroy();
    windowManager.removeListener(this);
    exit(0);
  }

  // -- WindowListener callbacks --

  @override
  void onWindowClose() {
    hideWindow();
  }

  @override
  void onWindowFocus() {}

  @override
  void onWindowBlur() {}

  // -- TrayListener callbacks --

  @override
  void onTrayIconMouseDown() {
    onShow?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      onShow?.call();
    } else if (menuItem.key == 'exit_app') {
      onQuit?.call();
    }
  }
}
