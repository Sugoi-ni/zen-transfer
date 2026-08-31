import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/transfer_provider.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => TransferProvider(),
      child: const ZenTransferApp(),
    ),
  );
}
