import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyAutoAccept = 'auto_accept';
  static const _keyEncrypt = 'encrypted_transfers';
  static const _keyShowOnNetwork = 'show_on_local_network';
  static const _keyFavorites = 'favorite_device_ids';

  late SharedPreferences _prefs;

  bool autoAccept = false;
  bool encryptedTransfers = true;
  bool showOnLocalNetwork = true;
  List<String> favoriteDeviceIds = [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    autoAccept = _prefs.getBool(_keyAutoAccept) ?? false;
    encryptedTransfers = _prefs.getBool(_keyEncrypt) ?? true;
    showOnLocalNetwork = _prefs.getBool(_keyShowOnNetwork) ?? true;
    favoriteDeviceIds = _prefs.getStringList(_keyFavorites) ?? [];
  }

  bool isFavorite(String id) => favoriteDeviceIds.contains(id);

  Future<void> toggleFavorite(String id) async {
    if (favoriteDeviceIds.contains(id)) {
      favoriteDeviceIds.remove(id);
    } else {
      favoriteDeviceIds.add(id);
    }
    await _prefs.setStringList(_keyFavorites, favoriteDeviceIds);
  }

  Future<void> setAutoAccept(bool value) async {
    autoAccept = value;
    await _prefs.setBool(_keyAutoAccept, value);
  }

  Future<void> setEncryptedTransfers(bool value) async {
    encryptedTransfers = value;
    await _prefs.setBool(_keyEncrypt, value);
  }

  Future<void> setShowOnLocalNetwork(bool value) async {
    showOnLocalNetwork = value;
    await _prefs.setBool(_keyShowOnNetwork, value);
  }

  // -- Autostart (Windows only, via registry) --

  static const _keyAutoStart = 'autostart';
  bool autoStart = false;

  Future<void> readAutoStart() async {
    autoStart = _prefs.getBool(_keyAutoStart) ?? false;
  }

  Future<void> setAutoStart(bool value) async {
    autoStart = value;
    await _prefs.setBool(_keyAutoStart, value);

    if (value) {
      // Register in Windows Run key
      final exePath = Platform.resolvedExecutable;
      await Process.run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
        '/v',
        'ZenTransfer',
        '/t',
        'REG_SZ',
        '/d',
        '"$exePath" --hidden',
        '/f',
      ]);
    } else {
      // Remove from Windows Run key
      await Process.run('reg', [
        'delete',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
        '/v',
        'ZenTransfer',
        '/f',
      ]);
    }
  }
}
