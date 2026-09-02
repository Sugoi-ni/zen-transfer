import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../theme/zen_theme.dart';
import '../providers/transfer_provider.dart';
import '../models/transfer_data.dart';
import '../widgets/device_tile.dart';

class SendScreen extends StatefulWidget {
  final DiscoveredDevice? targetDevice;

  const SendScreen({super.key, this.targetDevice});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final TextEditingController _textController = TextEditingController();
  List<PlatformFile> _selectedFiles = [];
  bool _isSending = false;
  DiscoveredDevice? _selectedDevice;

  @override
  void initState() {
    super.initState();
    _selectedDevice = widget.targetDevice;
    // Directly open file picker — no intermediate menu
    if (widget.targetDevice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickFiles();
      });
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result.isNotEmpty) {
        setState(() => _selectedFiles = result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file picker')),
        );
      }
    }
  }

  Future<void> _sendFiles(DiscoveredDevice device) async {
    if (_selectedFiles.isEmpty) return;
    if (!mounted) return;
    setState(() => _isSending = true);

    final provider = context.read<TransferProvider>();
    int sentCount = 0;
    for (final file in _selectedFiles) {
      if (!mounted) break;
      try {
        final path = file.path;
        if (path != null && path.isNotEmpty) {
          await provider.sendFileToDevice(device, path);
          sentCount++;
        } else {
          final bytes = await file.readAsBytes();
          await provider.sendFileBytesToDevice(device, bytes, file.name);
          sentCount++;
        }
      } catch (e) {
        debugPrint('Error sending ${file.name}: $e');
      }
    }

    if (!mounted) return;
    setState(() => _isSending = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sentCount > 0 ? 'Sent $sentCount file(s)' : 'Failed to send'),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _sendText(DiscoveredDevice device) async {
    if (_textController.text.isEmpty) return;
    if (!mounted) return;
    setState(() => _isSending = true);

    final provider = context.read<TransferProvider>();
    await provider.sendTextToDevice(device, _textController.text);

    if (!mounted) return;
    setState(() => _isSending = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text sent!')),
      );
      Navigator.pop(context);
    }
  }

  void _showTextInput() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZenTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ZenTheme.darkBorderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Enter Text',
                  style: TextStyle(
                    color: ZenTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _textController,
                  maxLines: 5,
                  style: TextStyle(color: ZenTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Type or paste your text here...',
                    hintStyle: TextStyle(color: ZenTheme.textTertiary),
                    filled: true,
                    fillColor: ZenTheme.darkSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ZenTheme.darkBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ZenTheme.darkBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: ZenTheme.primaryPurple,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSending
                        ? null
                        : _selectedDevice != null
                            ? () {
                                final device = _selectedDevice;
                                if (device != null) _sendText(device);
                              }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZenTheme.primaryPurple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Send Text',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: onTap != null ? ZenTheme.darkCard : ZenTheme.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onTap != null ? ZenTheme.darkBorder : ZenTheme.darkBorder.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: onTap != null ? ZenTheme.primaryPurple : ZenTheme.textTertiary,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: onTap != null ? ZenTheme.textPrimary : ZenTheme.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZenTheme.darkBg,
      appBar: AppBar(
        title: Text('Send'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Selected files
          if (_selectedFiles.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.attach_file_rounded,
                    color: ZenTheme.primaryPurple,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${_selectedFiles.length} file(s) selected',
                    style: TextStyle(
                      color: ZenTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedFiles = []),
                    child: Text(
                      'Clear',
                      style: TextStyle(color: ZenTheme.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _selectedFiles.length,
                itemBuilder: (context, index) {
                  final file = _selectedFiles[index];
                  return Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ZenTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ZenTheme.darkBorder),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.insert_drive_file_rounded,
                          color: ZenTheme.accentPurple,
                          size: 24,
                        ),
                        SizedBox(height: 4),
                        Text(
                          file.name,
                          style: TextStyle(
                            color: ZenTheme.textPrimary,
                            fontSize: 10,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Divider(color: ZenTheme.darkBorder),
          ],

          // Devices list
          Expanded(
            child: Consumer<TransferProvider>(
              builder: (context, provider, _) {
                if (provider.devices.isEmpty) {
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
                            border: Border.all(
                              color: ZenTheme.darkBorder,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.devices_rounded,
                            size: 36,
                            color: ZenTheme.primaryPurple.withValues(alpha: 0.4),
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'No devices found',
                          style: TextStyle(
                            color: ZenTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 16),
                        InkWell(
                          onTap: () => provider.scanDevices(),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: ZenTheme.darkCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ZenTheme.darkBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.radar_rounded,
                                  color: ZenTheme.primaryPurple,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Scan Again',
                                  style: TextStyle(
                                    color: ZenTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.devices.length,
                  itemBuilder: (context, index) {
                    final device = provider.devices[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DeviceTile(
                        device: device,
                        colorIndex: index,
                        onTap: () {
                          _selectedDevice = device;
                          if (_selectedFiles.isNotEmpty) {
                            _sendFiles(device);
                          } else {
                            _pickFiles();
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Bottom actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Text button
                _buildBottomAction(
                  icon: Icons.text_fields_rounded,
                  label: 'Text',
                  onTap: _selectedDevice != null ? _showTextInput : null,
                ),
                const SizedBox(width: 10),
                // Clipboard button
                _buildBottomAction(
                  icon: Icons.content_paste_rounded,
                  label: 'Clipboard',
                  onTap: _selectedDevice != null ? () async {
                    final device = _selectedDevice;
                    if (device == null) return;
                    if (!mounted) return;
                    final provider = context.read<TransferProvider>();
                    await provider.sendClipboardToDevice(device);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Clipboard sent!')),
                      );
                      Navigator.pop(context);
                    }
                  } : null,
                ),
                const SizedBox(width: 10),
                // Main action: file picker or send
                Expanded(
                  child: _selectedFiles.isNotEmpty
                      ? ElevatedButton.icon(
                          onPressed: _isSending
                              ? null
                              : () {
                                  final device = _selectedDevice;
                                  if (device != null) {
                                    _sendFiles(device);
                                  } else {
                                    _pickFiles();
                                  }
                                },
                          icon: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 20),
                          label: Text(
                            _isSending
                                ? 'Sending...'
                                : 'Send ${_selectedFiles.length} file(s)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ZenTheme.primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: const Text('Select Files'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: ZenTheme.darkBorderLight),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
