import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/zen_theme.dart';
import '../providers/transfer_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<TransferProvider>();
    _nameController.text = provider.deviceName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZenTheme.darkBg,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: ZenTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settings'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Device name
          _buildSection(
            title: 'DEVICE',
            children: [
              TextField(
                controller: _nameController,
                style: TextStyle(color: ZenTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Device Name',
                  labelStyle: TextStyle(color: ZenTheme.textSecondary),
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
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    context.read<TransferProvider>().initialize(value.trim());
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Transfer settings
          _buildSection(
            title: 'TRANSFER',
            children: [
              Consumer<TransferProvider>(
                builder: (context, provider, _) => Column(
                  children: [
                    _buildSwitchTile(
                      title: 'Auto-accept transfers',
                      subtitle: 'Accept incoming transfers without confirmation',
                      value: provider.autoAccept,
                      onChanged: (v) => provider.setAutoAccept(v),
                    ),
                    // Auto-accept helper text
                    Padding(
                      padding: const EdgeInsets.only(left: 2, top: 2, bottom: 6),
                      child: Text(
                        'Only auto-accepts from favorite devices',
                        style: TextStyle(
                          color: ZenTheme.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    _buildSwitchTile(
                      title: 'Encrypt transfers',
                      subtitle: 'Use AES-256 encryption for all transfers',
                      value: provider.encryptedTransfers,
                      onChanged: (v) => provider.setEncryptedTransfers(v),
                    ),
                    _buildSwitchTile(
                      title: 'Show on local network',
                      subtitle: 'Make this device discoverable',
                      value: provider.showOnLocalNetwork,
                      onChanged: (v) => provider.setShowOnLocalNetwork(v),
                    ),
                    _buildSwitchTile(
                      title: 'Mirror notifications to PC',
                      subtitle: 'Send phone notifications to connected PC',
                      value: provider.notificationMirroring,
                      onChanged: provider.setNotificationMirroring,
                    ),
                    _buildSwitchTile(
                      title: 'Clipboard sync',
                      subtitle: 'Share clipboard with PC on copy',
                      value: provider.clipboardSync,
                      onChanged: (v) => provider.setClipboardSync(v),
                    ),
                    if (Platform.isWindows)
                      _buildSwitchTile(
                        title: 'Start with Windows',
                        subtitle: 'Launch minimized to tray when you log in',
                        value: provider.autoStart,
                        onChanged: (v) => provider.setAutoStart(v),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Data
          _buildSection(
            title: 'DATA',
            children: [
              _buildActionTile(
                icon: Icons.delete_sweep_rounded,
                iconColor: Colors.redAccent,
                title: 'Clear transfer history',
                subtitle: 'Remove all past transfer records',
                onTap: () => _showClearHistoryDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // About
          _buildSection(
            title: 'ABOUT',
            children: [
              _buildInfoTile(title: 'Version', value: '1.0.0'),
              _buildInfoTile(title: 'Encryption', value: 'AES-256-CBC'),
              _buildInfoTile(title: 'Protocol', value: 'TCP + UDP'),
            ],
          ),
          const SizedBox(height: 32),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final provider = context.read<TransferProvider>();
                final newName = _nameController.text.trim();

                if (newName.isNotEmpty && newName != provider.deviceName) {
                  await provider.changeDeviceName(newName);
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings saved')),
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ZenTheme.primaryPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: ZenTheme.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ZenTheme.darkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZenTheme.darkBorder),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ZenTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: ZenTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: ZenTheme.primaryPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ZenTheme.textPrimary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: ZenTheme.textTertiary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: ZenTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: ZenTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: ZenTheme.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZenTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear Transfer History',
          style: TextStyle(color: ZenTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will remove all past transfer records. This action cannot be undone.',
          style: TextStyle(color: ZenTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ZenTheme.textTertiary)),
          ),
          TextButton(
            onPressed: () {
              context.read<TransferProvider>().clearHistory();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transfer history cleared')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
