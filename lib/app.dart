import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/zen_theme.dart';
import 'screens/home_screen.dart';

class ZenTransferApp extends StatelessWidget {
  const ZenTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: ZenTheme.darkSurface,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    return MaterialApp(
      title: 'ZenTransfer',
      debugShowCheckedModeBanner: false,
      theme: ZenTheme.theme,
      home: const HomeScreen(),
    );
  }
}
