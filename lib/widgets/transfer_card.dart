import 'dart:io';
import 'package:flutter/foundation.dart';
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
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final bool showActions;

  const TransferCard({
    super.key,
    required this.transfer,
    this.onDownload,
    this.onPause,
    this.onResume,
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
    final isPaused = transfer.status == TransferStatus.paused;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZenTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive || isPaused
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
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transfer.fileName ?? transfer.textContent ?? 'Text',
                      style: TextStyle(
                        color: ZenTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          transfer.senderName,
                          style: TextStyle(
                            color: ZenTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: ZenTheme.textTertiary,
                          ),
                        ),
                        Text(
                          transfer.receiverName,
                          style: TextStyle(
                            color: ZenTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatTimestamp(transfer.timestamp),
                      style: TextStyle(
                        color: ZenTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(),
            ],
          ),

          // ── Progress ──
          if ((transfer.status == TransferStatus.transferring ||
                  transfer.status == TransferStatus.paused) &&
              transfer.fileSize != null &&
              transfer.fileSize! > 0) ...[
            SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: transfer.progress,
                backgroundColor: ZenTheme.darkBorder,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isPaused ? ZenTheme.warning : ZenTheme.primaryPurple,
                ),
                minHeight: 4,
              ),
            ),
            SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatFileSize(transfer.transferredBytes)} / ${_formatFileSize(transfer.fileSize!)}',
                  style: TextStyle(
                    color: ZenTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
                // Speed + ETA display
                if (transfer.speed != null || transfer.eta != null)
                  Row(
                    children: [
                      if (transfer.speed != null) ...[
                        Icon(
                          Icons.speed_rounded,
                          size: 12,
                          color: ZenTheme.textTertiary,
                        ),
                        SizedBox(width: 3),
                        Text(
                          '${TransferService.formatSize(transfer.speed!.toInt())}/s',
                          style: TextStyle(
                            color: ZenTheme.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (transfer.speed != null && transfer.eta != null)
                        Text(
                          ' · ',
                          style: TextStyle(
                            color: ZenTheme.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      if (transfer.eta != null)
                        Text(
                          _formatEta(transfer.eta!),
                          style: TextStyle(
                            color: ZenTheme.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                Text(
                  '${(transfer.progress * 100).toInt()}%',
                  style: TextStyle(
                    color: ZenTheme.primaryPurple,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          // ── Pause/Resume button ──
          if (showActions &&
              (transfer.status == TransferStatus.transferring ||
                  transfer.status == TransferStatus.paused) &&
              transfer.fileSize != null &&
              transfer.fileSize! > 0) ...[
            SizedBox(height: 10),
            Row(
              children: [
                if (transfer.status == TransferStatus.transferring)
                  _buildActionButton(
                    icon: Icons.pause_rounded,
                    label: 'Pause',
                    color: ZenTheme.warning,
                    onTap: onPause ?? () {},
                  ),
                if (transfer.status == TransferStatus.paused)
                  _buildActionButton(
                    icon: Icons.play_arrow_rounded,
                    label: 'Resume',
                    color: ZenTheme.success,
                    onTap: onResume ?? () {},
                  ),
              ],
            ),
          ],

          // ── File preview thumbnail (completed files) ──
          if (isCompleted && _isPreviewable()) ...[
            SizedBox(height: 10),
            GestureDetector(
              onTap: () => _openPreview(context),
              child: _buildThumbnail(),
            ),
          ],

          // ── File size ──
          if (transfer.type == TransferType.file &&
              transfer.fileSize != null &&
              transfer.fileSize! > 0 &&
              transfer.status != TransferStatus.transferring &&
              transfer.status != TransferStatus.paused) ...[
            SizedBox(height: 6),
            Text(
              _formatFileSize(transfer.fileSize!),
              style: TextStyle(
                color: ZenTheme.textTertiary,
                fontSize: 11,
              ),
            ),
          ],

          // ── Error ──
          if (transfer.error != null) ...[
            SizedBox(height: 8),
            Text(
              transfer.error!,
              style: TextStyle(
                color: ZenTheme.error,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // ── Download button ──
          if (showActions && isDownloadPending) ...[
            SizedBox(height: 12),
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
            SizedBox(height: 12),
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
                if (defaultTargetPlatform != TargetPlatform.windows) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.share_rounded,
                      label: 'Share',
                      color: ZenTheme.accentPurple,
                      onTap: () => _shareFile(context),
                    ),
                  ),
                ],
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

  /// Check if file can be previewed (images, videos, audio, text)
  bool _isPreviewable() {
    if (transfer.filePath == null) return false;
    final ext = transfer.fileName?.split('.').last.toLowerCase() ?? '';
    return FileTypeHelper.previewableExtensions.contains(ext);
  }

  /// Build thumbnail preview for completed files
  Widget _buildThumbnail() {
    final filePath = transfer.filePath!;
    final ext = transfer.fileName?.split('.').last.toLowerCase() ?? '';

    // Image preview
    if (FileTypeHelper.isImage(ext)) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 160,
            width: double.infinity,
            child: Image.file(
              File(filePath),
              fit: BoxFit.contain,
              cacheWidth: 320,
              cacheHeight: 320,
              errorBuilder: (_, _, _) => _buildPlaceholderThumb(),
            ),
          ),
        ),
      );
    }

    // Video preview — show placeholder with play icon
    if (FileTypeHelper.isVideo(ext)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 80,
          width: double.infinity,
          color: ZenTheme.darkSurface,
          child: Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: ZenTheme.primaryPurple,
              size: 40,
            ),
          ),
        ),
      );
    }

    // Audio preview — show waveform-style placeholder
    if (FileTypeHelper.isAudio(ext)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 60,
          width: double.infinity,
          color: ZenTheme.darkSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.audio_file_rounded,
                color: ZenTheme.accentPurple,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio file',
                      style: TextStyle(
                        color: ZenTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        _AudioWaveBar(height: 8),
                        _AudioWaveBar(height: 14),
                        _AudioWaveBar(height: 10),
                        _AudioWaveBar(height: 18),
                        _AudioWaveBar(height: 6),
                        _AudioWaveBar(height: 12),
                        _AudioWaveBar(height: 8),
                        _AudioWaveBar(height: 16),
                        _AudioWaveBar(height: 10),
                        _AudioWaveBar(height: 6),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Text file preview
    if (FileTypeHelper.isText(ext)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 80,
          width: double.infinity,
          color: ZenTheme.darkSurface,
          padding: const EdgeInsets.all(12),
          child: FutureBuilder<String>(
            future: _readTextPreview(),
            builder: (_, snapshot) {
              if (snapshot.hasData) {
                return Text(
                  snapshot.data!,
                  style: TextStyle(
                    color: ZenTheme.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                );
              }
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            },
          ),
        ),
      );
    }

    return _buildPlaceholderThumb();
  }

  Widget _buildPlaceholderThumb() {
    return Container(
      height: 80,
      width: double.infinity,
      color: ZenTheme.darkSurface,
      child: Center(
        child: Icon(
          FileTypeHelper.getIcon(transfer.fileName ?? 'unknown'),
          color: ZenTheme.textTertiary,
          size: 32,
        ),
      ),
    );
  }

  Future<String> _readTextPreview() async {
    try {
      final file = File(transfer.filePath!);
      final content = await file.readAsString();
      return content.length > 300 ? '${content.substring(0, 300)}...' : content;
    } catch (_) {
      return '[Could not read file]';
    }
  }

  String _formatEta(double seconds) {
    if (seconds < 60) return '${seconds.toInt()}s left';
    if (seconds < 3600) {
      final min = (seconds / 60).floor();
      final sec = (seconds % 60).toInt();
      return '${min}m ${sec}s left';
    }
    final hr = (seconds / 3600).floor();
    final min = ((seconds % 3600) / 60).floor();
    return '${hr}h ${min}m left';
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
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
      case TransferStatus.paused:
        color = ZenTheme.warning;
        text = 'Paused';
        icon = Icons.pause_circle_rounded;
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

    if (defaultTargetPlatform == TargetPlatform.windows) {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: ${result.message}')),
        );
      }
    } else {
      await SharePlus.instance.share(ShareParams(files: [XFile(filePath)]));
    }
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

  void _openPreview(BuildContext context) {
    final filePath = transfer.filePath;
    if (filePath == null) return;
    final ext = transfer.fileName?.split('.').last.toLowerCase() ?? '';

    if (FileTypeHelper.isImage(ext)) {
      showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (ctx) => GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Image.file(
                  File(filePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      _openFile(context);
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'Today $h:$m';
    }
    if (diff.inDays < 2) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'Yesterday $h:$m';
    }
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} $h:$m';
  }
}

/// Small audio wave bar widget
class _AudioWaveBar extends StatelessWidget {
  final double height;

  const _AudioWaveBar({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: ZenTheme.accentPurple.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
