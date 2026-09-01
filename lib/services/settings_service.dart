import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyAutoAccept = 'auto_accept';
  static const _keyEncrypt = 'encrypted_transfers';
  static const _keyShowOnNetwork = 'show_on_local_network';
  static const _keyIsLight = 'is_light_mode';

  late SharedPreferences _prefs;

  bool autoAccept = false;
  bool encryptedTransfers = true;
  bool showOnLocalNetwork = true;
  bool isLightMode = false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    autoAccept = _prefs.getBool(_keyAutoAccept) ?? false;
    encryptedTransfers = _prefs.getBool(_keyEncrypt) ?? true;
    showOnLocalNetwork = _prefs.getBool(_keyShowOnNetwork) ?? true;
    isLightMode = _prefs.getBool(_keyIsLight) ?? false;
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

  Future<void> setLightMode(bool value) async {
    isLightMode = value;
    await _prefs.setBool(_keyIsLight, value);
  }
}
