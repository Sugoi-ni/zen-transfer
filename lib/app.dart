import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/zen_theme.dart';
import 'screens/home_screen.dart';
import 'providers/transfer_provider.dart';

class ZenTransferApp extends StatelessWidget {
  const ZenTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransferProvider>(
      builder: (context, provider, _) {
        final isLight = provider.isLightMode;
        ZenTheme.isLight = isLight;

        // Set system UI overlay style
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: ZenTheme.darkSurface,
          systemNavigationBarIconBrightness:
              isLight ? Brightness.dark : Brightness.light,
        ));

        return MaterialApp(
          title: 'ZenTransfer',
          debugShowCheckedModeBanner: false,
          theme: ZenTheme.theme,
          home: const HomeScreen(),
        );
      },
    );
  }
}