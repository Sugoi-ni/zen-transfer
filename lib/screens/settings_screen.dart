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
          icon: const Icon(Icons.arrow_back_rounded, color: ZenTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings'),
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
                style: const TextStyle(color: ZenTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Device Name',
                  labelStyle: const TextStyle(color: ZenTheme.textSecondary),
                  filled: true,
                  fillColor: ZenTheme.darkSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ZenTheme.darkBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ZenTheme.darkBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
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
                  ],
                ),
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
          style: const TextStyle(
            color: ZenTheme.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
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
                  style: const TextStyle(
                    color: ZenTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
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
            activeColor: ZenTheme.primaryPurple,
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
            style: const TextStyle(
              color: ZenTheme.textPrimary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: ZenTheme.textTertiary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
