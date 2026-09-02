import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/zen_theme.dart';
import '../models/transfer_data.dart';
import '../providers/transfer_provider.dart';
import '../widgets/transfer_card.dart';

class BoxScreen extends StatefulWidget {
  const BoxScreen({super.key});

  @override
  State<BoxScreen> createState() => _BoxScreenState();
}

class _BoxScreenState extends State<BoxScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZenTheme.darkBg,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: ZenTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Incoming Files'),
        centerTitle: false,
      ),
      body: Consumer<TransferProvider>(
        builder: (context, provider, _) {
          final boxFiles = provider.boxFiles;

          if (boxFiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: ZenTheme.darkCard,
                      shape: BoxShape.circle,
                      border: Border.all(color: ZenTheme.darkBorder, width: 2),
                    ),
                    child: Icon(
                      Icons.inbox_rounded,
                      size: 36,
                      color: ZenTheme.primaryPurple.withValues(alpha: 0.4),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'No incoming files',
                    style: TextStyle(
                      color: ZenTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Files from other devices\nwill appear here',
                    style: TextStyle(
                      color: ZenTheme.textTertiary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: boxFiles.length,
            itemBuilder: (context, index) {
              final transfer = boxFiles[index];
              final isPending = transfer.status == TransferStatus.pending;
              return TransferCard(
                transfer: transfer,
                onDownload: isPending
                    ? () => provider.downloadFile(transfer.id)
                    : null,
                showActions: true,
              );
            },
          );
        },
      ),
    );
  }
}
