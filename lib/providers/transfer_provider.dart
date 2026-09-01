import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transfer_data.dart';
import '../theme/zen_theme.dart';
import '../services/local_network_service.dart';
import '../services/settings_service.dart';
import '../services/transfer_service.dart';
import '../services/clipboard_service.dart';

class TransferProvider extends ChangeNotifier {
  final LocalNetworkService _networkService = LocalNetworkService();
  final ClipboardService _clipboardService = ClipboardService();
  final SettingsService _settingsService = SettingsService();
  late TransferService _transferService;

  List<DiscoveredDevice> _devices = [];
  List<TransferData> _transferHistory = [];
  TransferData? _activeTransfer;
  String _deviceName = '';
  bool _isServerRunning = false;
  bool _isScanning = false;

  /// File data waiting to be downloaded (keyed by transfer ID)
  final Map<String, Uint8List> _pendingDownloads = {};

  /// Map from IncomingTransfer.id to TransferData.id for tracking
  final Map<String, String> _incomingToTransferId = {};

  /// Number of unseen pending downloads (for badge)
  int _pendingDownloadsCount = 0;

  /// Timer for refreshing speed/ETA display
  Timer? _speedRefreshTimer;

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
  bool get isLightMode => _settingsService.isLightMode;

  TransferProvider() {
    _transferService = TransferService(_networkService);
    _listenToTransfers();
    _listenToIncoming();
    _startSpeedRefreshTimer();
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

  void _listenToTransfers() {
    _transferService.transferStream.listen((transfer) {
      _activeTransfer = transfer;

      if (transfer.status == TransferStatus.completed ||
          transfer.status == TransferStatus.failed) {
        _transferHistory.insert(0, transfer);
        if (_transferHistory.length > 50) {
          _transferHistory = _transferHistory.sublist(0, 50);
        }
        _saveHistory();
      } else if (transfer.status == TransferStatus.transferring ||
          transfer.status == TransferStatus.paused) {
        // Update or insert active transfer in history
        final idx = _transferHistory.indexWhere((t) => t.id == transfer.id);
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

      // Store file data in memory for later download
      if (incoming.fileData != null) {
        _pendingDownloads[transferId] = incoming.fileData!;
      }

      // Auto-accept: save immediately without waiting for user tap
      if (_settingsService.autoAccept) {
        debugPrint('Auto-accept enabled — saving file directly');
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
    }
  }

  /// Handle incoming text — auto-copy to clipboard
  void _handleIncomingText(IncomingTransfer incoming) async {
    if (incoming.status == 'completed' && incoming.textContent != null) {
      await _clipboardService.copyText(incoming.textContent!);

      _transferHistory.insert(0, TransferData(
        id: 'txt_${DateTime.now().millisecondsSinceEpoch}',
        senderName: incoming.senderName,
        receiverName: _deviceName,
        type: TransferType.text,
        status: TransferStatus.completed,
        textContent: incoming.textContent,
        fileSize: utf8.encode(incoming.textContent!).length,
        transferredBytes: utf8.encode(incoming.textContent!).length,
        mode: ConnectionMode.local,
      ));
      _saveHistory();
    }
  }

  /// Download a received file — save to disk with progress
  Future<void> downloadFile(String transferId) async {
    final data = _pendingDownloads[transferId];
    if (data == null) {
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
      // Save file to disk with progress updates
      final fileName = transfer.fileName ?? 'unknown_file';
      debugPrint('Downloading file: $fileName (${data.length} bytes)');
      final savedPath = await _transferService.saveReceivedFile(
        fileName: fileName,
        data: data,
        onProgress: (written, total) {
          final i = _transferHistory.indexWhere((t) => t.id == transferId);
          if (i != -1) {
            _transferHistory[i] = _transferHistory[i].copyWith(
              transferredBytes: written,
            );
            notifyListeners();
          }
        },
      );

      debugPrint('File saved to: $savedPath');

      // Update to completed
      final i = _transferHistory.indexWhere((t) => t.id == transferId);
      if (i != -1) {
        _transferHistory[i] = _transferHistory[i].copyWith(
          status: TransferStatus.completed,
          filePath: savedPath,
          transferredBytes: data.length,
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

  /// Initialize the provider with device name
  Future<void> initialize(String name) async {
    debugPrint('=== Provider Init: $name ===');
    _deviceName = name;

    // Load persisted settings
    await _settingsService.init();
    ZenTheme.isLight = _settingsService.isLightMode;
    debugPrint('Settings loaded: autoAccept=${_settingsService.autoAccept}, '
        'encrypt=${_settingsService.encryptedTransfers}, '
        'visible=${_settingsService.showOnLocalNetwork}, '
        'lightMode=${_settingsService.isLightMode}');

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

  // ---- Settings ----

  /// Update auto-accept setting
  Future<void> setAutoAccept(bool value) async {
    await _settingsService.setAutoAccept(value);
    notifyListeners();
  }

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

  /// Update light/dark theme
  Future<void> setLightMode(bool value) async {
    await _settingsService.setLightMode(value);
    ZenTheme.isLight = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _speedRefreshTimer?.cancel();
    _networkService.stop();
    _transferService.dispose();
    super.dispose();
  }
}
