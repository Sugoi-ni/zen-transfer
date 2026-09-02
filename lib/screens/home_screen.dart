import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/zen_theme.dart';
import '../providers/transfer_provider.dart';
import '../services/share_service.dart';
import '../widgets/device_tile.dart';
import '../widgets/transfer_card.dart';
import '../models/transfer_data.dart';
import 'package:file_picker/file_picker.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  AppLifecycleListener? _lifecycleListener;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
    // Android: catch share intents that arrive while the app is already
    // running (onNewIntent). When the user returns from the share sheet
    // the app transitions to `resumed`, so we re-check for shared content.
    if (defaultTargetPlatform == TargetPlatform.android) {
      _lifecycleListener = AppLifecycleListener(
        onResume: () {
          if (_isInitialized) {
            _checkSharedContent();
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  /// Check if the app was opened via Android share sheet
  Future<void> _checkSharedContent() async {
    final provider = context.read<TransferProvider>();
    // Wait for provider init (device name needed for receiverName)
    await Future.delayed(const Duration(milliseconds: 300));
    final content = await ShareService().getSharedContent();
    if (content.isEmpty || !mounted) return;

    if (content.isText && content.text != null && content.text!.isNotEmpty) {
      debugPrint('Shared text: ${content.text!.length} chars');
      await _showShareTargetPicker(
        title: 'Send shared text to',
        subtitle: '${content.text!.length} characters',
        onDeviceSelected: (device) async {
          await provider.sendTextToDevice(device, content.text!);
        },
      );
    } else if (content.isFiles) {
      debugPrint('Shared files: ${content.files.length}');
      await _showShareTargetPicker(
        title: 'Send ${content.files.length} file(s) to',
        subtitle: content.files.map((f) => f.name).join(', '),
        onDeviceSelected: (device) async {
          for (final file in content.files) {
            final bytes = await ShareService().readSharedFile(file.uri);
            if (bytes.isNotEmpty) {
              await provider.sendFileBytesToDevice(device, bytes, file.name);
            }
          }
        },
      );
    }
  }

  /// Show device picker for shared content, then send to selection
  Future<void> _showShareTargetPicker({
    required String title,
    required String subtitle,
    required Future<void> Function(DiscoveredDevice device) onDeviceSelected,
  }) async {
    if (!mounted) return;
    final device = await showModalBottomSheet<DiscoveredDevice>(
      context: context,
      backgroundColor: ZenTheme.darkCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<TransferProvider>(
          builder: (context, provider, _) {
            final devices = provider.devices;
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      title,
                      style: TextStyle(
                        color: ZenTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: ZenTheme.textTertiary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 16),
                    if (devices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            Text(
                              'No devices found',
                              style: TextStyle(
                                color: ZenTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => provider.scanDevices(),
                              icon: const Icon(Icons.radar_rounded, size: 18),
                              label: const Text('Scan for devices'),
                            ),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
                            final device = devices[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: DeviceTile(
                                device: device,
                                colorIndex: index,
                                onTap: () => Navigator.pop(ctx, device),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (device != null && mounted) {
      await onDeviceSelected(device);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content sent!')),
        );
      }
    }
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
    // Android share sheet content (if app opened via share)
    if (defaultTargetPlatform == TargetPlatform.android) {
      _checkSharedContent();
      // Also catch shares that arrive while the app is already running:
      // Kotlin pushes an event on every new SEND intent (onNewIntent), and
      // this fires the same device-picker flow.
      ShareService().onNewShare = () {
        _checkSharedContent();
      };
    }
    _isInitialized = true;
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
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 14),
                  Column(
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
            Divider(color: ZenTheme.darkBorder, height: 1),
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
                context.read<TransferProvider>().clearPendingCount();
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
            SizedBox(height: 8),
            Divider(color: ZenTheme.darkBorder, height: 1),
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
                SizedBox(width: 14),
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
                      icon: Icon(
                        Icons.menu_rounded,
                        color: ZenTheme.textSecondary,
                        size: 24,
                      ),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    SizedBox(width: 4),
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
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
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
                            style: TextStyle(
                              color: ZenTheme.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Settings icon
                    IconButton(
                      icon: Icon(
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
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ZenTheme.primaryPurple,
                            ),
                          )
                        else
                          Icon(
                            Icons.radar_rounded,
                            color: ZenTheme.primaryPurple,
                            size: 20,
                          ),
                        SizedBox(width: 10),
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
              SliverToBoxAdapter(
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
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: DeviceTile(
                          device: provider.devices[index],
                          colorIndex: index,
                          onTap: () => _selectDevice(provider.devices[index]),
                        ),
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
                        SizedBox(height: 24),
                        Text(
                          'No devices found',
                          style: TextStyle(
                            color: ZenTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
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
                (provider.activeTransfer!.status == TransferStatus.transferring ||
                 provider.activeTransfer!.status == TransferStatus.paused)) ...[
              SliverToBoxAdapter(
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
                  showActions: true,
                  onPause: () => provider.pauseTransfer(),
                  onResume: () => provider.resumeTransfer(),
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
                SizedBox(height: 20),
                Text(
                  'No transfers yet',
                  style: TextStyle(
                    color: ZenTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                Text(
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
          decoration: BoxDecoration(
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
                    onTap: () {
                      setState(() => _currentIndex = 1);
                      provider.clearPendingCount();
                    },
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
                  SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
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
                  decoration: BoxDecoration(
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ZenTheme.darkBorderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Device info
              Center(
                child: Container(
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
              ),
              const SizedBox(height: 14),
              Text(
                device.name,
                style: TextStyle(
                  color: ZenTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '${device.platform} • ${device.ip}',
                style: TextStyle(
                  color: ZenTheme.textTertiary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Action buttons
              _buildSheetAction(
                icon: Icons.insert_drive_file_rounded,
                label: 'Send Files',
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final result = await FilePicker.pickFiles(type: FileType.any);
                    if (result.isNotEmpty && mounted) {
                      _showFileReviewSheet(device, result);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open file picker')),
                      );
                    }
                  }
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
            SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: ZenTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: ZenTheme.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showFileReviewSheet(DiscoveredDevice device, List<PlatformFile> files) {
    bool isSending = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: ZenTheme.darkCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ZenTheme.darkBorderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  'Send to ${device.name}',
                  style: TextStyle(
                    color: ZenTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${files.length} file(s) selected',
                  style: TextStyle(
                    color: ZenTheme.textTertiary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                // File list
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: files.length,
                    itemBuilder: (ctx, index) {
                      final file = files[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: ZenTheme.darkSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ZenTheme.darkBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.insert_drive_file_rounded,
                              color: ZenTheme.primaryPurple,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                file.name,
                                style: TextStyle(
                                  color: ZenTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Send button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isSending ? null : () async {
                      setSheetState(() => isSending = true);
                      final provider = context.read<TransferProvider>();
                      int sentCount = 0;
                      for (final file in files) {
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
                      if (mounted) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(sentCount > 0 ? 'Sent $sentCount file(s)' : 'Failed to send'),
                          ),
                        );
                      }
                    },
                    icon: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                    label: Text(
                      isSending ? 'Sending...' : 'Send ${files.length} file(s)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZenTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
          side: BorderSide(color: ZenTheme.darkBorder),
        ),
        title: Text(
          'Send Text',
          style: TextStyle(color: ZenTheme.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: TextStyle(color: ZenTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter text to send...',
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
              borderSide: BorderSide(color: ZenTheme.primaryPurple, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ZenTheme.textSecondary)),
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
