import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/zen_theme.dart';
import '../providers/transfer_provider.dart';
import '../widgets/device_tile.dart';
import '../widgets/transfer_card.dart';
import '../models/transfer_data.dart';
import 'send_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    final provider = context.read<TransferProvider>();
    if (provider.deviceName.isEmpty) {
      final autoName = await _getAutoDeviceName();
      debugPrint('Auto device name: $autoName');
      await provider.initialize(autoName);
    } else {
      await provider.initialize(provider.deviceName);
    }
  }

  Future<String> _getAutoDeviceName() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        const channel = MethodChannel('com.example.zen_transfer/device_name');
        final name = await channel.invokeMethod<String>('getDeviceName');
        if (name != null && name.isNotEmpty) return name;
      } catch (_) {}
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      try {
        final name = Platform.localHostname;
        if (name.isNotEmpty && name != 'localhost') return name;
      } catch (_) {}
    }
    return defaultTargetPlatform.name == 'Android' ? 'Android Device' : 'PC';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeTab(),
            _buildBoxTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ═══════════════════════════════════════════
  //  DRAWER
  // ═══════════════════════════════════════════
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: ZenTheme.darkSurface,
      width: 280,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: ZenTheme.purpleGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: ZenTheme.primaryPurple.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.swap_horiz_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ZenTransfer',
                        style: TextStyle(
                          color: ZenTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'v1.0.0',
                        style: TextStyle(
                          color: ZenTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: ZenTheme.darkBorder, height: 1),
            const SizedBox(height: 8),
            _buildDrawerItem(
              icon: Icons.home_rounded,
              label: 'Home',
              isActive: _currentIndex == 0,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),
            _buildDrawerItem(
              icon: Icons.inbox_rounded,
              label: 'Incoming Files',
              isActive: _currentIndex == 1,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 1);
              },
            ),
            _buildDrawerItem(
              icon: Icons.history_rounded,
              label: 'History',
              isActive: _currentIndex == 2,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 2);
              },
            ),
            const SizedBox(height: 8),
            const Divider(color: ZenTheme.darkBorder, height: 1),
            const SizedBox(height: 8),
            _buildDrawerItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isActive
            ? ZenTheme.primaryPurple.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? ZenTheme.primaryPurple : ZenTheme.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? ZenTheme.primaryPurple : ZenTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  HOME TAB — Device-centric layout
  // ═══════════════════════════════════════════
  Widget _buildHomeTab() {
    return Consumer<TransferProvider>(
      builder: (context, provider, _) {
        return CustomScrollView(
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.menu_rounded,
                        color: ZenTheme.textSecondary,
                        size: 24,
                      ),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: ZenTheme.purpleGradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: ZenTheme.primaryPurple.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ZenTransfer',
                            style: TextStyle(
                              color: ZenTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            provider.isServerRunning
                                ? provider.deviceName
                                : 'Starting...',
                            style: const TextStyle(
                              color: ZenTheme.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Settings icon
                    IconButton(
                      icon: const Icon(
                        Icons.settings_rounded,
                        color: ZenTheme.textTertiary,
                        size: 22,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Scan Button ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: InkWell(
                  onTap: provider.isScanning ? null : () => provider.scanDevices(),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: ZenTheme.darkCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: provider.isScanning
                            ? ZenTheme.primaryPurple.withValues(alpha: 0.3)
                            : ZenTheme.darkBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (provider.isScanning)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ZenTheme.primaryPurple,
                            ),
                          )
                        else
                          const Icon(
                            Icons.radar_rounded,
                            color: ZenTheme.primaryPurple,
                            size: 20,
                          ),
                        const SizedBox(width: 10),
                        Text(
                          provider.isScanning ? 'Scanning...' : 'Scan for Devices',
                          style: TextStyle(
                            color: provider.isScanning
                                ? ZenTheme.primaryPurple
                                : ZenTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Devices Section ──
            if (provider.devices.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 28, 20, 14),
                  child: Text(
                    'NEARBY DEVICES',
                    style: TextStyle(
                      color: ZenTheme.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return DeviceTile(
                        device: provider.devices[index],
                        colorIndex: index,
                        onTap: () => _selectDevice(provider.devices[index]),
                      );
                    },
                    childCount: provider.devices.length,
                  ),
                ),
              ),
            ],

            // ── Empty State ──
            if (provider.devices.isEmpty && !provider.isScanning)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
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
                            size: 48,
                            color: ZenTheme.primaryPurple.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'No devices found',
                          style: TextStyle(
                            color: ZenTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Make sure both devices are on\nthe same WiFi network',
                          style: TextStyle(
                            color: ZenTheme.textTertiary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Active Transfer ──
            if (provider.activeTransfer != null &&
                provider.activeTransfer!.status == TransferStatus.transferring) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 28, 20, 14),
                  child: Text(
                    'ACTIVE TRANSFER',
                    style: TextStyle(
                      color: ZenTheme.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: TransferCard(
                  transfer: provider.activeTransfer!,
                  showActions: false,
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  //  BOX TAB
  // ═══════════════════════════════════════════
  Widget _buildBoxTab() {
    return Consumer<TransferProvider>(
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
                const SizedBox(height: 20),
                const Text(
                  'No incoming files',
                  style: TextStyle(
                    color: ZenTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
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
    );
  }

  // ═══════════════════════════════════════════
  //  HISTORY TAB
  // ═══════════════════════════════════════════
  Widget _buildHistoryTab() {
    return Consumer<TransferProvider>(
      builder: (context, provider, _) {
        if (provider.transferHistory.isEmpty) {
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
                    Icons.history_rounded,
                    size: 36,
                    color: ZenTheme.primaryPurple.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No transfers yet',
                  style: TextStyle(
                    color: ZenTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your transfer history\nwill appear here',
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
          itemCount: provider.transferHistory.length,
          itemBuilder: (context, index) {
            return TransferCard(
              transfer: provider.transferHistory[index],
              showActions: false,
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  //  BOTTOM NAV
  // ═══════════════════════════════════════════
  Widget _buildBottomNav() {
    return Consumer<TransferProvider>(
      builder: (context, provider, _) {
        return Container(
          decoration: const BoxDecoration(
            color: ZenTheme.darkSurface,
            border: Border(
              top: BorderSide(color: ZenTheme.darkBorder, width: 0.5),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    isActive: _currentIndex == 0,
                    onTap: () => setState(() => _currentIndex = 0),
                  ),
                  _buildNavItem(
                    icon: Icons.inbox_rounded,
                    label: 'Box',
                    isActive: _currentIndex == 1,
                    badge: provider.pendingDownloadsCount,
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                  _buildNavItem(
                    icon: Icons.history_rounded,
                    label: 'History',
                    isActive: _currentIndex == 2,
                    onTap: () => setState(() => _currentIndex = 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: isActive
            ? BoxDecoration(
                color: ZenTheme.primaryPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? ZenTheme.primaryPurple : ZenTheme.textTertiary,
                  size: 22,
                ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: ZenTheme.primaryPurple,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
            if (badge > 0 && !isActive)
              Positioned(
                right: -8,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: ZenTheme.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  DEVICE SELECT BOTTOM SHEET
  // ═══════════════════════════════════════════
  void _selectDevice(DiscoveredDevice device) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZenTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
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
              const SizedBox(height: 20),
              // Device info
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: ZenTheme.deviceGradient(0),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ZenTheme.deviceColors[0].withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _getDeviceIcon(device.platform),
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                device.name,
                style: const TextStyle(
                  color: ZenTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${device.platform} • ${device.ip}',
                style: const TextStyle(
                  color: ZenTheme.textTertiary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 28),
              // Action buttons
              _buildSheetAction(
                icon: Icons.insert_drive_file_rounded,
                label: 'Send Files',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SendScreen(targetDevice: device),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildSheetAction(
                icon: Icons.folder_rounded,
                label: 'Send Folder',
                onTap: () async {
                  Navigator.pop(ctx);
                  // Use method channel for folder picker
                  try {
                    final result = await MethodChannel('com.zen.transfer/file_picker')
                        .invokeMethod<String>('pickFolder');
                    if (result != null && mounted) {
                      final provider = context.read<TransferProvider>();
                      await provider.sendFolderToDevice(device, result);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Folder sent!')),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
              _buildSheetAction(
                icon: Icons.text_fields_rounded,
                label: 'Send Text',
                onTap: () {
                  Navigator.pop(ctx);
                  _showTextSendDialog(device);
                },
              ),
              const SizedBox(height: 10),
              _buildSheetAction(
                icon: Icons.content_paste_rounded,
                label: 'Send Clipboard',
                onTap: () async {
                  Navigator.pop(ctx);
                  final provider = context.read<TransferProvider>();
                  await provider.sendClipboardToDevice(device);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Clipboard sent!')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: ZenTheme.darkSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ZenTheme.darkBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: ZenTheme.primaryPurple, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                color: ZenTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right_rounded,
              color: ZenTheme.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.phone_android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'windows':
        return Icons.computer_rounded;
      case 'macos':
        return Icons.laptop_mac_rounded;
      case 'linux':
        return Icons.computer;
      default:
        return Icons.device_unknown_rounded;
    }
  }

  void _showTextSendDialog(DiscoveredDevice device) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZenTheme.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ZenTheme.darkBorder),
        ),
        title: const Text(
          'Send Text',
          style: TextStyle(color: ZenTheme.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: const TextStyle(color: ZenTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter text to send...',
            hintStyle: const TextStyle(color: ZenTheme.textTertiary),
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
              borderSide: const BorderSide(color: ZenTheme.primaryPurple, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: ZenTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                Navigator.pop(ctx);
                final provider = context.read<TransferProvider>();
                await provider.sendTextToDevice(device, controller.text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Text sent!')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ZenTheme.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
