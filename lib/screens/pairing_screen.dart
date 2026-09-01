import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/zen_theme.dart';
import '../providers/transfer_provider.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  String? _pinCode;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generatePin() {
    final provider = context.read<TransferProvider>();
    setState(() {
      _pinCode = provider.generatePin();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pair Devices'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated glow
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ZenTheme.primaryPurple.withValues(
                            alpha: _glowAnimation.value * 0.3,
                          ),
                          blurRadius: 40 + (_glowAnimation.value * 20),
                          spreadRadius: _glowAnimation.value * 10,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        ZenTheme.primaryPurple.withValues(alpha: 0.2),
                        ZenTheme.darkBg,
                      ],
                    ),
                    border: Border.all(
                      color: ZenTheme.primaryPurple.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: _pinCode != null
                      ? Center(
                          child: Text(
                            _pinCode!,
                            style: TextStyle(
                              color: ZenTheme.textPrimary,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.lock_rounded,
                          color: ZenTheme.primaryPurple,
                          size: 60,
                        ),
                ),
              ),
              SizedBox(height: 32),
              Text(
                _pinCode != null ? 'Share this PIN' : 'Generate PIN',
                style: TextStyle(
                  color: ZenTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _pinCode != null
                    ? 'Enter this PIN on the other device\nto establish a secure connection'
                    : 'Generate a PIN to pair with\nanother ZenTransfer device',
                style: TextStyle(
                  color: ZenTheme.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),

              // QR Code
              if (_pinCode != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                    child: QrImageView(
                    data: 'zentransfer://pair?pin=$_pinCode',
                    version: QrVersions.auto,
                    size: 160,
                    backgroundColor: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Or scan QR code',
                  style: TextStyle(
                    color: ZenTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 40),
              ],

              // Buttons
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _generatePin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZenTheme.primaryPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _pinCode != null
                            ? Icons.refresh_rounded
                            : Icons.vpn_key_rounded,
                        color: Colors.white,
                      ),
                      SizedBox(width: 10),
                      Text(
                        _pinCode != null ? 'Generate New PIN' : 'Generate PIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    // TODO: Enter PIN from other device
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: ZenTheme.primaryPurple,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.keyboard_rounded,
                        color: ZenTheme.primaryPurple,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Enter PIN',
                        style: TextStyle(
                          color: ZenTheme.primaryPurple,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
