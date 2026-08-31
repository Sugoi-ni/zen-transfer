import 'package:flutter/material.dart';
import '../theme/zen_theme.dart';
import '../models/transfer_data.dart';

class DeviceTile extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback onTap;
  final int colorIndex;

  const DeviceTile({
    super.key,
    required this.device,
    required this.onTap,
    this.colorIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = ZenTheme.deviceColors[colorIndex % ZenTheme.deviceColors.length];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ZenTheme.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ZenTheme.darkBorder, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular device avatar
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.8),
                    color.withValues(alpha: 0.4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _getDeviceIcon(),
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            // Device name
            Text(
              device.name,
              style: const TextStyle(
                color: ZenTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // Platform + IP
            Text(
              device.platform,
              style: const TextStyle(
                color: ZenTheme.textTertiary,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon() {
    switch (device.platform.toLowerCase()) {
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
}
