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
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: ZenTheme.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ZenTheme.darkBorder, width: 1),
        ),
        child: Row(
          children: [
            // Device avatar
            Container(
              width: 40,
              height: 40,
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
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _getDeviceIcon(),
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Device info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    device.name,
                    style: TextStyle(
                      color: ZenTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    device.platform,
                    style: TextStyle(
                      color: ZenTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow icon
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
