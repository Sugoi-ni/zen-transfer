import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transfer_data.dart';
import '../services/local_network_service.dart';
import '../services/settings_service.dart';
import '../services/transfer_service.dart';
import '../services/clipboard_service.dart';
import '../services/clipboard_sync_service.dart';
import '../services/notification_mirror_service.dart';
import 'package:local_notifier/local_notifier.dart';

class TransferProvider extends ChangeNotifier {
  final LocalNetworkService _networkService = LocalNetworkService();
  final ClipboardService _clipboardService = ClipboardService();
  final SettingsService _settingsService = SettingsService();
  late TransferService _transferService;
  final ClipboardSyncService _clipboardSyncService = ClipboardSyncService();
  final NotificationMirrorService _notificationMirrorService =
      NotificationMirrorService();
  StreamSubscription<Map<String, dynamic>>? _notifSub;

  List<DiscoveredDevice> _devices = [];
  List<TransferData> _transferHistory = [];
  TransferData? _activeTransfer;
  String _deviceName = '';
  bool _isServerRunning = false;
  bool _isScanning = false;

  /// File path waiting to be opened (keyed by transfer ID)
  final Map<String, String> _pendingDownloads = {};

  /// Map from IncomingTransfer.id to TransferData.id for tracking
  final Map<String, String> _incomingToTransferId = {};

  /// Number of unseen pending downloads (for badge)
  int _pendingDownloadsCount = 0;

  /// Timer for refreshing speed/ETA display
  Timer? _speedRefreshTimer;

  /// Timer for detecting stuck transfers (no progress for 60s)
  Timer? _stuckTransferTimer;

  /// Last progress timestamps for stuck detection
  final Map<String, int> _lastProgressBytes = {};
  final Map<String, DateTime> _lastProgressTime = {};

  // Getters
  List<DiscoveredDevice> get devices => _devices;
  List<TransferData> get transferHistory => _transferHistory;
  TransferData? get activeTransfer => _activeTransfer;
  bool get isServerRunning => _isServerRunning;
  bool get isScanning => _isScanning;
  String get deviceName => _deviceName;
  ClipboardService get clipboard => _clipboardService;
  int get pendingDownloadsCount => _pendingDownloadsCount;

  // Settings getters (delegated to SettingsService)
  bool get autoAccept => _settingsService.autoAccept;
  bool get encryptedTransfers => _settingsService.encryptedTransfers;
  bool get showOnLocalNetwork => _settingsService.showOnLocalNetwork;
  bool get notificationMirroring => _settingsService.notificationMirroring;
  bool get clipboardSync => _settingsService.clipboardSync;
  SettingsService get settingsService => _settingsService;

  TransferProvider() {
    _transferService = TransferService(_networkService);
    _listenToTransfers();
    _listenToIncoming();
    _startSpeedRefreshTimer();
    _startStuckTransferDetector();
  }

  /// Refresh speed/ETA display every second while transferring
  void _startSpeedRefreshTimer() {
    _speedRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeTransfer != null &&
          (_activeTransfer!.status == TransferStatus.transferring ||
           _activeTransfer!.status == TransferStatus.paused)) {
        notifyListeners(); // trigger UI rebuild with updated speed/eta
      }
    });
  }

  /// Detect stuck transfers — if no progress for 60s, mark as failed.
  /// Also catches transfers stuck at 100% (completed but event missed).
  void _startStuckTransferDetector() {
    _stuckTransferTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final now = DateTime.now();
      for (final transfer in _transferHistory) {
        if (transfer.status != TransferStatus.transferring) continue;
        if (transfer.type != TransferType.file) continue;

        // If at 100% — it's done, just the event was missed
        if (transfer.fileSize != null &&
            transfer.fileSize! > 0 &&
            transfer.transferredBytes >= transfer.fileSize!) {
          debugPrint('Transfer at 100% stuck as Sending: ${transfer.fileName} — marking completed');
          final idx = _transferHistory.indexWhere((t) => t.id == transfer.id);
          if (idx != -1) {
            _transferHistory[idx] = _transferHistory[idx].copyWith(
              status: TransferStatus.completed,
            );
          }
          _lastProgressBytes.remove(transfer.id);
          _lastProgressTime.remove(transfer.id);
          _saveHistory();
          continue;
        }

        final currentBytes = transfer.transferredBytes;
        final lastBytes = _lastProgressBytes[transfer.id];
        final lastTime = _lastProgressTime[transfer.id];

        if (lastBytes != null && lastTime != null) {
          if (currentBytes == lastBytes) {
            // No progress since last check
            final elapsed = now.difference(lastTime).inSeconds;
            if (elapsed >= 60) {
              debugPrint('Transfer stuck for ${elapsed}s: ${transfer.fileName} — marking failed');
              final idx = _transferHistory.indexWhere((t) => t.id == transfer.id);
              if (idx != -1) {
                _transferHistory[idx] = _transferHistory[idx].copyWith(
                  status: TransferStatus.failed,
                  error: 'Transfer timed out — no progress for ${elapsed}s',
                );
              }
              _lastProgressBytes.remove(transfer.id);
              _lastProgressTime.remove(transfer.id);
            }
          } else {
            // Progress happened, reset timer
            _lastProgressBytes[transfer.id] = currentBytes;
            _lastProgressTime[transfer.id] = now;
          }
        } else {
          // First time tracking this transfer
          _lastProgressBytes[transfer.id] = currentBytes;
          _lastProgressTime[transfer.id] = now;
        }
      }
      notifyListeners();
    });
  }

  void _listenToTransfers() {
    _transferService.transferStream.listen((transfer) {
      _activeTransfer = transfer;

      // Always update or insert — never duplicate
      final idx = _transferHistory.indexWhere((t) => t.id == transfer.id);

      if (transfer.status == TransferStatus.completed ||
          transfer.status == TransferStatus.failed) {
        if (idx != -1) {
          // Update existing entry in-place (no duplicate)
          _transferHistory[idx] = transfer;
        } else {
          _transferHistory.insert(0, transfer);
        }
        if (_transferHistory.length > 50) {
          _transferHistory = _transferHistory.sublist(0, 50);
        }
        // Clean up stuck detection tracking
        _lastProgressBytes.remove(transfer.id);
        _lastProgressTime.remove(transfer.id);
        _saveHistory();
      } else if (transfer.status == TransferStatus.transferring ||
          transfer.status == TransferStatus.paused) {
        // Update or insert active transfer in history
        if (idx != -1) {
          _transferHistory[idx] = transfer;
        } else {
          _transferHistory.insert(0, transfer);
        }
      }
      notifyListeners();
    });
  }

  /// Pause the active transfer
  void pauseTransfer() {
    _transferService.pauseTransfer();
    if (_activeTransfer != null) {
      _activeTransfer = _activeTransfer!.copyWith(
        status: TransferStatus.paused,
        isPaused: true,
      );
      notifyListeners();
    }
  }

  /// Resume the active transfer
  void resumeTransfer() {
    _transferService.resumeTransfer();
    if (_activeTransfer != null) {
      _activeTransfer = _activeTransfer!.copyWith(
        status: TransferStatus.transferring,
        isPaused: false,
      );
      notifyListeners();
    }
  }

  void _listenToIncoming() {
    _networkService.incomingStream.listen((incoming) async {
      debugPrint('Incoming: type=${incoming.type}, status=${incoming.status}, id=${incoming.id}');

      if (incoming.type == IncomingTransferType.file) {
        _handleIncomingFile(incoming);
      } else if (incoming.type == IncomingTransferType.text) {
        _handleIncomingText(incoming);
      }

      notifyListeners();
    });
  }

  /// Handle incoming file — add to history with progress, store data for manual download
  void _handleIncomingFile(IncomingTransfer incoming) {
    final existingId = _incomingToTransferId[incoming.id];

    if (incoming.status == 'receiving') {
      // Progress update during TCP receive
      if (existingId != null) {
        // Update existing transfer's progress
        final idx = _transferHistory.indexWhere((t) => t.id == existingId);
        if (idx != -1) {
          _transferHistory[idx] = _transferHistory[idx].copyWith(
            transferredBytes: incoming.receivedBytes,
          );
        }
      } else {
        // First time seeing this file — add to history
        final transferId = 'inc_${incoming.id}';
        _incomingToTransferId[incoming.id] = transferId;

        _transferHistory.insert(0, TransferData(
          id: transferId,
          senderName: incoming.senderName,
          receiverName: _deviceName,
          type: TransferType.file,
          status: TransferStatus.transferring,
          fileName: incoming.fileName,
          fileSize: incoming.fileSize,
          transferredBytes: incoming.receivedBytes,
          mode: ConnectionMode.local,
        ));
      }
    } else if (incoming.status == 'received') {
      // File fully received over TCP — store data, show Download button
      final transferId = _incomingToTransferId[incoming.id] ?? 'inc_${incoming.id}';
      _incomingToTransferId[incoming.id] = transferId;

      if (incoming.filePath != null) {
        _pendingDownloads[transferId] = incoming.filePath!;
      }

      // Auto-accept: save immediately without waiting for user tap
      // Only auto-accept if autoAccept is on AND sender is a favorite device
      if (_settingsService.autoAccept && _isSenderFavorite(incoming.senderName)) {
        debugPrint('Auto-accept enabled — saving file directly (favorite device)');
        // Fire and forget — downloadFile updates transfer in-place
        downloadFile(transferId);
      } else {
        // Increment badge count only when manual approval needed
        _pendingDownloadsCount++;

        // Update transfer to "pending download" status
        final idx = _transferHistory.indexWhere((t) => t.id == transferId);
        if (idx != -1) {
          _transferHistory[idx] = _transferHistory[idx].copyWith(
            status: TransferStatus.pending,
            transferredBytes: incoming.fileSize ?? incoming.receivedBytes,
          );
        } else {
          _transferHistory.insert(0, TransferData(
            id: transferId,
            senderName: incoming.senderName,
            receiverName: _deviceName,
            type: TransferType.file,
            status: TransferStatus.pending,
            fileName: incoming.fileName,
            fileSize: incoming.fileSize,
            transferredBytes: incoming.fileSize ?? incoming.receivedBytes,
            mode: ConnectionMode.local,
          ));
        }
      }
    } else if (incoming.status == 'checksum_mismatch') {
      // Integrity check failed on receiver — discard data, surface as failed
      final transferId = _incomingToTransferId[incoming.id] ?? 'inc_${incoming.id}';
      _incomingToTransferId[incoming.id] = transferId;
      _pendingDownloads.remove(transferId);

      final idx = _transferHistory.indexWhere((t) => t.id == transferId);
      if (idx != -1) {
        _transferHistory[idx] = _transferHistory[idx].copyWith(
          status: TransferStatus.failed,
          error: 'Checksum mismatch — data corrupted in transit',
        );
      } else {
        _transferHistory.insert(0, TransferData(
          id: transferId,
          senderName: incoming.senderName,
          receiverName: _deviceName,
          type: TransferType.file,
          status: TransferStatus.failed,
          fileName: incoming.fileName,
          fileSize: incoming.fileSize,
          mode: ConnectionMode.local,
          error: 'Checksum mismatch — data corrupted in transit',
        ));
      }
      _saveHistory();
    }
  }

  /// Handle incoming text — auto-copy to clipboard or show notification toast
  void _handleIncomingText(IncomingTransfer incoming) async {
    if (incoming.status == 'completed' && incoming.textContent != null) {
      final text = incoming.textContent!;

      // Check if this is a mirrored notification (JSON with type == 'notification')
      Map<String, dynamic>? notif;
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic> && decoded['type'] == 'notification') {
          notif = decoded;
        }
      } catch (_) {
        // Not JSON — treat as regular text
      }

      if (notif != null && defaultTargetPlatform == TargetPlatform.windows) {
        // Show toast via local_notifier instead of polluting clipboard
        try {
          if (!_localNotifierInitialized) {
            // ignore: avoid_dynamic_calls
            await _initLocalNotifier();
          }
          _showNotificationToast(
            notif['title'] as String? ?? 'Notification',
            notif['text'] as String? ?? '',
          );
        } catch (e) {
          debugPrint('local_notifier error: $e');
        }

        // Add to history as a notification (no clipboard copy)
        _transferHistory.insert(0, TransferData(
          id: 'txt_${DateTime.now().millisecondsSinceEpoch}',
          senderName: incoming.senderName,
          receiverName: _deviceName,
          type: TransferType.text,
          status: TransferStatus.completed,
          textContent: '[Notification] ${notif['title'] ?? ''}: ${notif['text'] ?? ''}',
          fileSize: utf8.encode(text).length,
          transferredBytes: utf8.encode(text).length,
          mode: ConnectionMode.local,
        ));
      } else {
        // Regular text — copy to clipboard as before
        await _clipboardService.copyText(text);

        // Echo suppression: mark as "seen" so the clipboard poller doesn't
        // immediately send this PC-originated text back to the PC.
        _lastSentClipboard = text;

        _transferHistory.insert(0, TransferData(
          id: 'txt_${DateTime.now().millisecondsSinceEpoch}',
          senderName: incoming.senderName,
          receiverName: _deviceName,
          type: TransferType.text,
          status: TransferStatus.completed,
          textContent: text,
          fileSize: utf8.encode(text).length,
          transferredBytes: utf8.encode(text).length,
          mode: ConnectionMode.local,
        ));
      }
      _saveHistory();
    }
  }

  // -- local_notifier for Windows toast notifications --

  bool _localNotifierInitialized = false;

  Future<void> _initLocalNotifier() async {
    if (defaultTargetPlatform != TargetPlatform.windows) return;
    try {
      await localNotifier.setup(
        appName: 'ZenTransfer',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _localNotifierInitialized = true;
    } catch (e) {
      debugPrint('local_notifier init failed: $e');
    }
  }

  void _showNotificationToast(String title, String body) {
    if (defaultTargetPlatform != TargetPlatform.windows) return;
    try {
      final notification = LocalNotification(
        title: title,
        body: body,
      );
      notification.show();
    } catch (e) {
      debugPrint('Toast show error: $e');
    }
  }

  /// Download a received file — save to disk with progress
  Future<void> downloadFile(String transferId) async {
    final filePath = _pendingDownloads[transferId];
    if (filePath == null) {
      debugPrint('No pending data for $transferId');
      return;
    }

    final idx = _transferHistory.indexWhere((t) => t.id == transferId);
    if (idx == -1) {
      debugPrint('Transfer not found: $transferId');
      return;
    }

    final transfer = _transferHistory[idx];

    // Update status to downloading
    _transferHistory[idx] = transfer.copyWith(
      status: TransferStatus.transferring,
      transferredBytes: 0,
    );
    notifyListeners();

    try {
      // File already saved to disk by LocalNetworkService — just open it
      final savedPath = filePath; // file is already on disk
      debugPrint('Opening file: $savedPath');

      // Update to completed with filePath
      final i = _transferHistory.indexWhere((t) => t.id == transferId);
      if (i != -1) {
        _transferHistory[i] = _transferHistory[i].copyWith(
          status: TransferStatus.completed,
          filePath: savedPath,
          transferredBytes: transfer.fileSize ?? 0,
        );
      }

      // Remove from pending
      _pendingDownloads.remove(transferId);
      _saveHistory();
    } catch (e) {
      debugPrint('Download error: $e');
      final i = _transferHistory.indexWhere((t) => t.id == transferId);
      if (i != -1) {
        _transferHistory[i] = _transferHistory[i].copyWith(
          status: TransferStatus.failed,
          error: e.toString(),
        );
      }
    }
    notifyListeners();
  }

  /// Get pending downloads (files waiting to be saved)
  List<TransferData> get pendingDownloads =>
      _transferHistory.where((t) =>
          t.status == TransferStatus.pending &&
          t.type == TransferType.file).toList();

  /// Get all files for the Box (incoming: pending + completed with file path)
  List<TransferData> get boxFiles =>
      _transferHistory.where((t) =>
          t.type == TransferType.file &&
          t.id.startsWith('inc_')).toList();

  /// Clear badge count (called when box screen opens)
  void clearPendingCount() {
    if (_pendingDownloadsCount > 0) {
      _pendingDownloadsCount = 0;
      notifyListeners();
    }
  }

  /// Request storage permission on Android
  Future<void> _requestStoragePermission() async {
    try {
      if (await Permission.manageExternalStorage.isGranted) {
        debugPrint('MANAGE_EXTERNAL_STORAGE already granted');
        return;
      }

      final status = await Permission.manageExternalStorage.request();
      debugPrint('MANAGE_EXTERNAL_STORAGE status: $status');

      if (!status.isGranted) {
        // Fallback: try WRITE_EXTERNAL_STORAGE
        final writeStatus = await Permission.storage.request();
        debugPrint('WRITE_EXTERNAL_STORAGE status: $writeStatus');
      }
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
  }

  /// Save history to disk
  void _saveHistory() {
    _transferService.saveHistory(_transferHistory);
  }

  /// Clear all transfer history
  void clearHistory() {
    _transferHistory.clear();
    _lastProgressBytes.clear();
    _lastProgressTime.clear();
    _saveHistory();
    notifyListeners();
  }

  /// Initialize the provider with device name
  Future<void> initialize(String name) async {
    debugPrint('=== Provider Init: $name ===');
    _deviceName = name;

    // Load persisted settings
    await _settingsService.init();
    await _settingsService.readAutoStart();
    debugPrint('Settings loaded: autoAccept=${_settingsService.autoAccept}, '
        'encrypt=${_settingsService.encryptedTransfers}, '
        'visible=${_settingsService.showOnLocalNetwork}');

    // Start clipboard sync + notification mirroring
    _startClipboardSync();
    _setupNotificationMirroring();

    // Request storage permission on Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _requestStoragePermission();
    }

    // Load persisted history
    try {
      _transferHistory = await _transferService.loadHistory();
      debugPrint('Loaded ${_transferHistory.length} history items');
    } catch (e) {
      debugPrint('History load error: $e');
    }

    // Start server only if "show on network" is enabled
    if (_settingsService.showOnLocalNetwork) {
      try {
        await _networkService.startServer(name);
        _isServerRunning = true;
        debugPrint('Server started successfully');
      } catch (e) {
        debugPrint('Server start error: $e');
        _isServerRunning = false;
      }
    } else {
      debugPrint('Server NOT started — showOnLocalNetwork is OFF');
      _isServerRunning = false;
    }

    // Listen for discovered devices
    _networkService.devicesStream.listen((devices) {
      _devices = devices;
      notifyListeners();
    });

    notifyListeners();
  }

  /// Scan for nearby devices
  Future<void> scanDevices() async {
    _isScanning = true;
    notifyListeners();

    try {
      _devices = await _networkService.scanForDevices();
    } catch (e) {
      debugPrint('Scan error: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Send file to a device
  Future<void> sendFileToDevice(
    DiscoveredDevice device,
    String filePath,
  ) async {
    await _transferService.sendFile(
      device,
      filePath,
      senderName: _deviceName,
      encrypted: _settingsService.encryptedTransfers,
    );
  }

  /// Send file bytes to a device (when path is unavailable)
  Future<void> sendFileBytesToDevice(
    DiscoveredDevice device,
    List<int> bytes,
    String fileName,
  ) async {
    await _transferService.sendFileBytes(
      device,
      bytes,
      fileName,
      senderName: _deviceName,
      encrypted: _settingsService.encryptedTransfers,
    );
  }

  /// Send text to a device
  Future<void> sendTextToDevice(
    DiscoveredDevice device,
    String text,
  ) async {
    await _transferService.sendText(
      device,
      text,
      senderName: _deviceName,
    );
  }

  /// Send clipboard content (text or image)
  Future<void> sendClipboardToDevice(DiscoveredDevice device) async {
    // Try image first
    final imageData = await _clipboardService.getImageData();
    if (imageData != null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _transferService.sendFileBytes(
        device,
        imageData,
        'clipboard_$timestamp.png',
        senderName: _deviceName,
        encrypted: _settingsService.encryptedTransfers,
      );
      return;
    }

    // Fall back to text
    final text = await _clipboardService.pasteText();
    if (text != null && text.isNotEmpty) {
      await _transferService.sendText(
        device,
        text,
        senderName: _deviceName,
      );
    }
  }

  /// Send folder to a device (zips first)
  Future<void> sendFolderToDevice(
    DiscoveredDevice device,
    String folderPath,
  ) async {
    await _transferService.sendFolder(
      device,
      folderPath,
      senderName: _deviceName,
      encrypted: _settingsService.encryptedTransfers,
    );
  }

  /// Get clipboard preview
  Future<String> getClipboardPreview() async {
    return await _clipboardService.getPreview();
  }

  /// Copy text to clipboard
  Future<void> copyToClipboard(String text) async {
    await _clipboardService.copyText(text);
  }

  /// Get formatted file size
  String formatSize(int bytes) => TransferService.formatSize(bytes);

  /// Generate a PIN for pairing (placeholder - not used in current flow)
  String generatePin() {
    final random = DateTime.now().millisecondsSinceEpoch % 1000000;
    return random.toString().padLeft(6, '0');
  }

  /// Change device name (restarts server with new name)
  Future<void> changeDeviceName(String newName) async {
    if (newName.isEmpty || newName == _deviceName) return;
    
    _deviceName = newName;
    
    // Stop old server
    _networkService.stop();
    _isServerRunning = false;
    
    // Restart with new name
    try {
      await _networkService.startServer(newName);
      _isServerRunning = true;
      debugPrint('Server restarted with name: $newName');
    } catch (e) {
      debugPrint('Server restart error: $e');
    }
    notifyListeners();
  }

  /// Check if sender name matches any favorite device's name
  bool _isSenderFavorite(String senderName) {
    // Match by sender name against discovered devices that are favorites
    for (final device in _devices) {
      if (_settingsService.isFavorite(device.id) &&
          device.name.toLowerCase() == senderName.toLowerCase()) {
        return true;
      }
    }
    // Fallback: senderName itself might be stored as a device id
    return _settingsService.isFavorite(senderName);
  }

  /// Retry a failed transfer (re-sends the file)
  Future<void> retryTransfer(TransferData transfer) async {
    if (transfer.status != TransferStatus.failed || transfer.filePath == null) {
      debugPrint('Cannot retry: status=${transfer.status}, filePath=${transfer.filePath}');
      return;
    }
    debugPrint('Retrying transfer: ${transfer.fileName} → ${transfer.senderName}');

    // Find the target device by name from discovered devices
    DiscoveredDevice? targetDevice;
    for (final device in _devices) {
      if (device.name.toLowerCase() == transfer.senderName.toLowerCase()) {
        targetDevice = device;
        break;
      }
    }

    // Reset the transfer in history to show it's active again
    final idx = _transferHistory.indexWhere((t) => t.id == transfer.id);
    if (idx != -1) {
      _transferHistory[idx] = _transferHistory[idx].copyWith(
        status: TransferStatus.pending,
        error: null,
        transferredBytes: 0,
      );
      notifyListeners();
    }

    if (targetDevice == null) {
      debugPrint('Cannot retry: device "${transfer.senderName}" not found in discovered devices');
      final i = _transferHistory.indexWhere((t) => t.id == transfer.id);
      if (i != -1) {
        _transferHistory[i] = _transferHistory[i].copyWith(
          status: TransferStatus.failed,
          error: 'Device "${transfer.senderName}" not found on network',
        );
      }
      notifyListeners();
      return;
    }

    // Re-send using the same file path with current encryption setting
    try {
      await _transferService.sendFile(
        targetDevice,
        transfer.filePath!,
        senderName: _deviceName,
        encrypted: _settingsService.encryptedTransfers,
      );
    } catch (e) {
      debugPrint('Retry send failed: $e');
      final i = _transferHistory.indexWhere((t) => t.id == transfer.id);
      if (i != -1) {
        _transferHistory[i] = _transferHistory[i].copyWith(
          status: TransferStatus.failed,
          error: e.toString(),
        );
      }
      notifyListeners();
    }
  }

  // ---- Settings ----

  /// Update auto-accept setting
  Future<void> setAutoAccept(bool value) async {
    await _settingsService.setAutoAccept(value);
    notifyListeners();
  }

  /// Toggle favorite status for a device
  Future<void> toggleFavorite(String deviceId) async {
    await _settingsService.toggleFavorite(deviceId);
    notifyListeners();
  }

  /// Check if a device is favorited
  bool isFavorite(String deviceId) => _settingsService.isFavorite(deviceId);

  /// Update autostart setting (Windows: HKCU Run registry key)
  Future<void> setAutoStart(bool value) async {
    await _settingsService.setAutoStart(value);
    notifyListeners();
  }

  /// Whether the app is registered to start with Windows
  bool get autoStart => _settingsService.autoStart;

  /// Update encryption setting
  Future<void> setEncryptedTransfers(bool value) async {
    await _settingsService.setEncryptedTransfers(value);
    notifyListeners();
  }

  /// Update show-on-network setting (toggles server on/off)
  Future<void> setShowOnLocalNetwork(bool value) async {
    await _settingsService.setShowOnLocalNetwork(value);

    if (value && !_isServerRunning) {
      // Turn ON — start server
      try {
        await _networkService.startServer(_deviceName);
        _isServerRunning = true;
        debugPrint('Server started (showOnNetwork toggled ON)');
      } catch (e) {
        debugPrint('Server start error: $e');
      }
    } else if (!value && _isServerRunning) {
      // Turn OFF — stop server and clear device list
      _networkService.stop();
      _isServerRunning = false;
      _devices = [];
      debugPrint('Server stopped (showOnNetwork toggled OFF)');
    }

    notifyListeners();
  }

  /// Update notification mirroring setting
  Future<void> setNotificationMirroring(bool value) async {
    await _settingsService.setNotificationMirroring(value);
    notifyListeners();
  }

  /// Update clipboard sync setting
  Future<void> setClipboardSync(bool value) async {
    await _settingsService.setClipboardSync(value);

    // Apply live: start/stop the clipboard poller without app restart
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (value) {
        _startClipboardSync();
      } else {
        _clipboardSyncService.stop();
        debugPrint('Clipboard sync stopped');
      }
    }

    notifyListeners();
  }

  // ---- Clipboard Sync (phone → PC) ----

  /// Start polling clipboard for changes on Android (phone side).
  void _startClipboardSync() {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (!_settingsService.clipboardSync) return;

    _clipboardSyncService.start(
      onText: (text) async => _sendClipboardText(text),
    );
    debugPrint('Clipboard sync started');
  }

  /// Send changed clipboard text to the first discovered PC.
  String? _lastSentClipboard;

  Future<void> _sendClipboardText(String text) async {
    // Deduplicate: skip if same as last sent
    if (text == _lastSentClipboard) return;
    _lastSentClipboard = text;

    if (_devices.isEmpty) {
      debugPrint('Clipboard sync: no devices found, skipping');
      return;
    }

    try {
      await _transferService.sendText(
        _devices.first,
        text,
        senderName: _deviceName,
      );
      debugPrint('Clipboard text sent to ${_devices.first.name}');
    } catch (e) {
      debugPrint('Clipboard sync send error: $e');
    }
  }

  // ---- Notification Mirroring (phone → PC) ----

  /// Set up the notification mirror stream.
  void _setupNotificationMirroring() {
    _notifSub = _notificationMirrorService.events.listen((notif) {
      if (!_settingsService.notificationMirroring) return;

      final title = notif['title'] as String? ?? '';
      final text = notif['text'] as String? ?? '';
      final pkg = notif['package'] as String? ?? '';
      _sendNotificationToPC(title, text, pkg);
    });
    debugPrint('Notification mirroring listener attached');
  }

  /// Send a mirrored notification to the first discovered PC as JSON text.
  Future<void> _sendNotificationToPC(
    String title,
    String text,
    String package,
  ) async {
    if (_devices.isEmpty) {
      debugPrint('Notification mirror: no devices found, skipping');
      return;
    }

    final payload = jsonEncode({
      'type': 'notification',
      'title': title,
      'text': text,
      'package': package,
    });

    try {
      await _transferService.sendText(
        _devices.first,
        payload,
        senderName: _deviceName,
      );
      debugPrint('Notification mirrored to ${_devices.first.name}');
    } catch (e) {
      debugPrint('Notification mirror send error: $e');
    }
  }

  @override
  void dispose() {
    _speedRefreshTimer?.cancel();
    _stuckTransferTimer?.cancel();
    _clipboardSyncService.stop();
    _notifSub?.cancel();
    _networkService.stop();
    _transferService.dispose();
    super.dispose();
  }
}
