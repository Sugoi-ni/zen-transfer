import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/zen_theme.dart';
import '../models/transfer_data.dart';
import '../services/transfer_service.dart';
import '../utils/file_type_helper.dart';

class TransferCard extends StatelessWidget {
  final TransferData transfer;
  final VoidCallback? onDownload;
  final bool showActions;

  const TransferCard({
    super.key,
    required this.transfer,
    this.onDownload,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloadPending =
        transfer.status == TransferStatus.pending &&
        transfer.type == TransferType.file;
    final isCompleted =
        transfer.status == TransferStatus.completed &&
        transfer.type == TransferType.file &&
        transfer.filePath != null;
    final isActive =
        transfer.status == TransferStatus.transferring ||
        transfer.status == TransferStatus.connecting;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZenTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? ZenTheme.primaryPurple.withValues(alpha: 0.3)
              : ZenTheme.darkBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main row ──
          Row(
            children: [
              _buildTypeIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transfer.fileName ?? transfer.textContent ?? 'Text',
                      style: const TextStyle(
                        color: ZenTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          transfer.senderName,
                          style: const TextStyle(
                            color: ZenTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: ZenTheme.textTertiary,
                          ),
                        ),
                        Text(
                          transfer.receiverName,
                          style: const TextStyle(
                            color: ZenTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildStatusChip(),
            ],
          ),

          // ── Progress ──
          if (transfer.status == TransferStatus.transferring &&
              transfer.fileSize != null &&
              transfer.fileSize! > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: transfer.progress,
                backgroundColor: ZenTheme.darkBorder,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ZenTheme.primaryPurple,
                ),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatFileSize(transfer.transferredBytes)} / ${_formatFileSize(transfer.fileSize!)}',
                  style: const TextStyle(
                    color: ZenTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${(transfer.progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: ZenTheme.primaryPurple,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          // ── File size ──
          if (transfer.type == TransferType.file &&
              transfer.fileSize != null &&
              transfer.fileSize! > 0 &&
              transfer.status != TransferStatus.transferring) ...[
            const SizedBox(height: 6),
            Text(
              _formatFileSize(transfer.fileSize!),
              style: const TextStyle(
                color: ZenTheme.textTertiary,
                fontSize: 11,
              ),
            ),
          ],

          // ── Error ──
          if (transfer.error != null) ...[
            const SizedBox(height: 8),
            Text(
              transfer.error!,
              style: const TextStyle(
                color: ZenTheme.error,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // ── Download button ──
          if (showActions && isDownloadPending) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _buildActionButton(
                icon: Icons.download_rounded,
                label: 'Download',
                color: ZenTheme.primaryPurple,
                onTap: onDownload ?? () {},
              ),
            ),
          ],

          // ── Action buttons ──
          if (showActions && isCompleted) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.open_in_new_rounded,
                    label: 'Open',
                    color: ZenTheme.primaryPurple,
                    onTap: () => _openFile(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    color: ZenTheme.accentPurple,
                    onTap: () => _shareFile(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.folder_open_rounded,
                    label: 'Folder',
                    color: ZenTheme.textSecondary,
                    onTap: () => _openFolder(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) => TransferService.formatSize(bytes);

  Widget _buildTypeIcon() {
    IconData icon;
    Color color;

    switch (transfer.type) {
      case TransferType.file:
        // Use FileTypeHelper for file-specific icons
        final fileName = transfer.fileName ?? 'unknown';
        icon = FileTypeHelper.getIcon(fileName);
        color = FileTypeHelper.getColor(fileName);
        break;
      case TransferType.text:
        icon = Icons.text_fields_rounded;
        color = ZenTheme.success;
        break;
      case TransferType.clipboard:
        icon = Icons.content_paste_rounded;
        color = ZenTheme.warning;
        break;
      case TransferType.screenshot:
        icon = Icons.screenshot_rounded;
        color = ZenTheme.info;
        break;
      case TransferType.image:
        icon = Icons.image_rounded;
        color = ZenTheme.error;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String text;
    IconData icon;

    switch (transfer.status) {
      case TransferStatus.pending:
        color = ZenTheme.warning;
        text = 'Pending';
        icon = Icons.schedule_rounded;
        break;
      case TransferStatus.connecting:
        color = ZenTheme.warning;
        text = 'Connecting';
        icon = Icons.wifi_find_rounded;
        break;
      case TransferStatus.transferring:
        color = ZenTheme.primaryPurple;
        text = transfer.type == TransferType.file && onDownload != null
            ? 'Downloading'
            : 'Sending';
        icon = Icons.sync_rounded;
        break;
      case TransferStatus.completed:
        color = ZenTheme.success;
        text = 'Done';
        icon = Icons.check_circle_rounded;
        break;
      case TransferStatus.failed:
        color = ZenTheme.error;
        text = 'Failed';
        icon = Icons.error_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(BuildContext context) async {
    final filePath = transfer.filePath;
    if (filePath == null) return;
    final file = File(filePath);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File not found')),
        );
      }
      return;
    }
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: ${result.message}')),
      );
    }
  }

  Future<void> _shareFile(BuildContext context) async {
    final filePath = transfer.filePath;
    if (filePath == null) return;
    final file = File(filePath);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File not found')),
        );
      }
      return;
    }
    await SharePlus.instance.share(ShareParams(files: [XFile(filePath)]));
  }

  Future<void> _openFolder(BuildContext context) async {
    final filePath = transfer.filePath;
    if (filePath == null) return;
    final file = File(filePath);
    if (!await file.exists()) return;
    final result = await OpenFilex.open(file.parent.path);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open folder: ${result.message}')),
      );
    }
  }
}
