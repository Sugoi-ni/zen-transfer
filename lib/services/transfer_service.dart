import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transfer_data.dart';
import 'encryption_service.dart';
import 'local_network_service.dart';

class TransferService {
  final LocalNetworkService _networkService;

  final StreamController<TransferData> _transferController =
      StreamController.broadcast();

  Stream<TransferData> get transferStream => _transferController.stream;

  /// Pause state for active transfer
  bool _isPaused = false;
  Completer<void>? _pauseCompleter;

  TransferService(this._networkService);

  /// Pause the active transfer
  void pauseTransfer() {
    _isPaused = true;
    _pauseCompleter = Completer<void>();
    debugPrint('Transfer paused');
  }

  /// Resume the active transfer
  void resumeTransfer() {
    _isPaused = false;
    if (_pauseCompleter != null && !_pauseCompleter!.isCompleted) {
      _pauseCompleter!.complete();
    }
    _pauseCompleter = null;
    debugPrint('Transfer resumed');
  }

  /// Check if transfer should pause — call between chunks
  Future<void> _checkPause() async {
    if (_isPaused && _pauseCompleter != null) {
      await _pauseCompleter!.future;
    }
  }

  // ═══════════════════════════════════════════
  //  FILE SEND — Chunked streaming
  // ═══════════════════════════════════════════
  Future<void> sendFile(
    DiscoveredDevice device,
    String filePath, {
    String? fileName,
    String? senderName,
    bool encrypted = false,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    final name = fileName ?? filePath.split(Platform.pathSeparator).last;
    var fileSize = await file.length();
    final sender = senderName ?? 'Local';

    final transfer = TransferData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderName: sender,
      receiverName: device.name,
      type: TransferType.file,
      status: TransferStatus.connecting,
      filePath: filePath,
      fileName: name,
      fileSize: fileSize,
      mode: ConnectionMode.local,
    );

    _transferController.add(transfer);

    // Compute sha256 checksum of original plain bytes (before encryption)
    final originalBytes = await file.readAsBytes();
    final fileChecksum = sha256.convert(originalBytes).toString();

    EncryptionService? encService;
    if (encrypted) {
      encService = EncryptionService();
      debugPrint('Encryption enabled — key will be sent in header');
    }

    Socket? socket;
    _isPaused = false;
    try {
      socket = await _networkService.connectToDevice(device);

      // For encryption, encrypt the pre-read plain bytes
      Uint8List? encryptedData;
      int sendSize = fileSize;
      if (encrypted && encService != null) {
        encryptedData = encService.encryptData(originalBytes);
        sendSize = encryptedData.length;
        debugPrint('File encrypted: $fileSize -> $sendSize bytes');
      }

      // Send file header (includes checksum for receiver verification)
      final header = jsonEncode({
        'type': 'file_header',
        'fileName': name,
        'fileSize': sendSize,
        'originalSize': fileSize,
        'senderName': sender,
        'encrypted': encrypted,
        'checksum': fileChecksum,
        if (encrypted) 'encKey': encService?.keyBase64,
        if (encrypted) 'encIv': encService?.ivBase64,
      });
      socket.add(Uint8List.fromList(utf8.encode(header)));
      try { await socket.flush(); } catch (_) {}

      // Wait for ACK
      final ackData = await socket.first.timeout(const Duration(seconds: 5));
      final ackMsg = utf8.decode(ackData);
      final ack = jsonDecode(ackMsg);
      if (ack['type'] != 'ack') {
        throw Exception('No ACK from receiver');
      }

      final startedAt = DateTime.now();
      _transferController.add(transfer.copyWith(
        status: TransferStatus.transferring,
        transferStartedAt: startedAt,
      ));

      // Stream data in 1MB chunks
      const chunkSize = 1024 * 1024;
      var sent = 0;

      if (encrypted && encryptedData != null) {
        // Stream encrypted data
        while (sent < encryptedData.length) {
          await _checkPause();
          final end = (sent + chunkSize).clamp(0, encryptedData.length);
          final chunk = encryptedData.sublist(sent, end);
          socket.add(chunk);
          sent += chunk.length;
          _transferController.add(transfer.copyWith(
            status: _isPaused ? TransferStatus.paused : TransferStatus.transferring,
            transferredBytes: sent,
            transferStartedAt: startedAt,
            isPaused: _isPaused,
          ));
        }
      } else {
        // Stream original bytes in 1MB chunks
        const chunkSize = 1024 * 1024;
        while (sent < originalBytes.length) {
          await _checkPause();
          final end = (sent + chunkSize).clamp(0, originalBytes.length);
          socket.add(originalBytes.sublist(sent, end));
          sent += end - sent;
          _transferController.add(transfer.copyWith(
            status: _isPaused ? TransferStatus.paused : TransferStatus.transferring,
            transferredBytes: sent,
            transferStartedAt: startedAt,
            isPaused: _isPaused,
          ));
        }
      }

      // Mark completed BEFORE flush/close — receiver already has all data.
      // flush/close can hang if the receiver closed its end, which would
      // leave the transfer stuck at 100% "Sending" forever.
      _transferController.add(transfer.copyWith(
        status: TransferStatus.completed,
        transferredBytes: fileSize,
      ));

      // Best-effort cleanup (non-blocking)
      try { await socket.flush(); } catch (_) {}
      try { await Future.delayed(const Duration(milliseconds: 200)); } catch (_) {}
      try { await socket.close(); } catch (_) {}
    } catch (e) {
      debugPrint('File send error: $e');
      _transferController.add(transfer.copyWith(
        status: TransferStatus.failed,
        error: e.toString(),
      ));
    } finally {
      try { socket?.destroy(); } catch (_) {}
    }
  }

  // ═══════════════════════════════════════════
  //  FILE BYTES SEND — for SAF / clipboard images
  // ═══════════════════════════════════════════
  Future<void> sendFileBytes(
    DiscoveredDevice device,
    List<int> bytes,
    String fileName, {
    String? senderName,
    bool encrypted = false,
  }) async {
    final sender = senderName ?? 'Local';
    var fileSize = bytes.length;

    // Compute sha256 checksum of original plain bytes (before encryption)
    final fileChecksum = sha256.convert(bytes).toString();

    final transfer = TransferData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderName: sender,
      receiverName: device.name,
      type: TransferType.file,
      status: TransferStatus.connecting,
      fileName: fileName,
      fileSize: fileSize,
      mode: ConnectionMode.local,
    );

    _transferController.add(transfer);

    EncryptionService? encService;
    if (encrypted) {
      encService = EncryptionService();
      debugPrint('Encryption enabled for bytes — key in header');
    }

    Socket? socket;
    _isPaused = false;
    try {
      socket = await _networkService.connectToDevice(device);

      Uint8List dataToSend;
      if (encrypted && encService != null) {
        dataToSend = encService.encryptData(Uint8List.fromList(bytes));
        debugPrint('Bytes encrypted: $fileSize -> ${dataToSend.length} bytes');
      } else {
        dataToSend = Uint8List.fromList(bytes);
      }

      final header = jsonEncode({
        'type': 'file_header',
        'fileName': fileName,
        'fileSize': dataToSend.length,
        'originalSize': fileSize,
        'senderName': sender,
        'encrypted': encrypted,
        'checksum': fileChecksum,
        if (encrypted) 'encKey': encService?.keyBase64,
        if (encrypted) 'encIv': encService?.ivBase64,
      });
      socket.add(Uint8List.fromList(utf8.encode(header)));
      try { await socket.flush(); } catch (_) {}

      final ackData = await socket.first.timeout(const Duration(seconds: 5));
      final ackMsg = utf8.decode(ackData);
      final ack = jsonDecode(ackMsg);
      if (ack['type'] != 'ack') {
        throw Exception('No ACK from receiver');
      }

      final startedAt = DateTime.now();
      _transferController.add(transfer.copyWith(
        status: TransferStatus.transferring,
        transferStartedAt: startedAt,
      ));

      // Stream in 1MB chunks
      const chunkSize = 1024 * 1024;
      var sent = 0;
      while (sent < dataToSend.length) {
        await _checkPause();
        final end = (sent + chunkSize).clamp(0, dataToSend.length);
        socket.add(dataToSend.sublist(sent, end));
        sent += end - sent;
        _transferController.add(transfer.copyWith(
          status: _isPaused ? TransferStatus.paused : TransferStatus.transferring,
          transferredBytes: sent,
          transferStartedAt: startedAt,
          isPaused: _isPaused,
        ));
      }

      // Mark completed BEFORE flush/close
      _transferController.add(transfer.copyWith(
        status: TransferStatus.completed,
        transferredBytes: fileSize,
      ));

      // Best-effort cleanup
      try { await socket.flush(); } catch (_) {}
      try { await Future.delayed(const Duration(milliseconds: 200)); } catch (_) {}
      try { await socket.close(); } catch (_) {}
    } catch (e) {
      debugPrint('File send error: $e');
      _transferController.add(transfer.copyWith(
        status: TransferStatus.failed,
        error: e.toString(),
      ));
    } finally {
      try { socket?.destroy(); } catch (_) {}
    }
  }

  // ═══════════════════════════════════════════
  //  FOLDER SEND — zip then send as file
  // ═══════════════════════════════════════════
  Future<void> sendFolder(
    DiscoveredDevice device,
    String folderPath, {
    String? senderName,
    bool encrypted = false,
  }) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      throw Exception('Folder not found: $folderPath');
    }

    final folderName = folderPath.split(Platform.pathSeparator).last;
    final zipName = '$folderName.zip';

    // Collect all files
    final files = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        files.add(entity.path);
      }
    }

    if (files.isEmpty) {
      throw Exception('Folder is empty');
    }

    debugPrint('Zipping $folderName: ${files.length} files');

    // Create zip archive
    final archive = Archive();
    for (final filePath in files) {
      final relativePath = filePath.substring(folderPath.length + 1);
      final fileBytes = await File(filePath).readAsBytes();
      archive.addFile(ArchiveFile(relativePath, fileBytes.length, fileBytes));
    }

    // Encode to zip
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw Exception('Failed to create zip archive');
    }

    debugPrint('Zip created: ${zipData.length} bytes');

    // Send zip as file
    await sendFileBytes(
      device,
      zipData,
      zipName,
      senderName: senderName,
      encrypted: encrypted,
    );
  }

  // ═══════════════════════════════════════════
  //  TEXT SEND
  // ═══════════════════════════════════════════
  Future<void> sendText(
    DiscoveredDevice device,
    String text, {
    String? senderName,
  }) async {
    final sender = senderName ?? 'Local';

    final transfer = TransferData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderName: sender,
      receiverName: device.name,
      type: TransferType.text,
      status: TransferStatus.connecting,
      textContent: text,
      fileSize: utf8.encode(text).length,
      mode: ConnectionMode.local,
    );

    _transferController.add(transfer);

    Socket? socket;
    try {
      socket = await _networkService.connectToDevice(device);

      _transferController.add(transfer.copyWith(
        status: TransferStatus.transferring,
      ));

      final header = jsonEncode({
        'type': 'text',
        'content': text,
        'senderName': sender,
      });

      socket.add(Uint8List.fromList(utf8.encode(header)));
      try { await socket.flush(); } catch (_) {}

      try {
        await socket.first.timeout(const Duration(seconds: 5));
      } catch (_) {}

      // Mark completed BEFORE close
      _transferController.add(transfer.copyWith(
        status: TransferStatus.completed,
        transferredBytes: transfer.fileSize!,
      ));

      try { await socket.close(); } catch (_) {}
    } catch (e) {
      debugPrint('Text send error: $e');
      _transferController.add(transfer.copyWith(
        status: TransferStatus.failed,
        error: e.toString(),
      ));
    } finally {
      try { socket?.destroy(); } catch (_) {}
    }
  }

  // ═══════════════════════════════════════════
  //  RETRY TRANSFER — re-sends a failed/pending transfer
  // ═══════════════════════════════════════════
  Future<void> retryTransfer(
    TransferData transfer,
    DiscoveredDevice device,
  ) async {
    if (transfer.type == TransferType.file && transfer.filePath != null) {
      await sendFile(
        device,
        transfer.filePath!,
        fileName: transfer.fileName,
        senderName: transfer.senderName,
      );
    } else if (transfer.type == TransferType.text && transfer.textContent != null) {
      await sendText(
        device,
        transfer.textContent!,
        senderName: transfer.senderName,
      );
    }
  }

  // ═══════════════════════════════════════════
  //  SAVE RECEIVED FILE
  // ═══════════════════════════════════════════
  Future<String> saveReceivedFile({
    required String fileName,
    required Uint8List data,
    void Function(int written, int total)? onProgress,
  }) async {
    Directory zenDir;
    if (defaultTargetPlatform == TargetPlatform.android) {
      zenDir = Directory('/storage/emulated/0/Download/ZenTransfer');
    } else {
      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      zenDir = Directory('${dir.path}${Platform.pathSeparator}ZenTransfer');
    }

    if (!await zenDir.exists()) {
      await zenDir.create(recursive: true);
    }

    var finalPath = '${zenDir.path}${Platform.pathSeparator}$fileName';
    var counter = 1;
    while (await File(finalPath).exists()) {
      final ext = fileName.contains('.') ? '.${fileName.split('.').last}' : '';
      final baseName = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;
      finalPath =
          '${zenDir.path}${Platform.pathSeparator}${baseName}_$counter$ext';
      counter++;
    }

    final file = File(finalPath);
    final sink = file.openWrite();
    const chunkSize = 1024 * 1024;
    var written = 0;

    while (written < data.length) {
      final end = (written + chunkSize).clamp(0, data.length);
      sink.add(data.sublist(written, end));
      written = end;
      onProgress?.call(written, data.length);
      await Future.delayed(Duration.zero);
    }

    await sink.close();
    debugPrint('File saved: $finalPath');
    return finalPath;
  }

  // ═══════════════════════════════════════════
  //  HISTORY PERSISTENCE
  // ═══════════════════════════════════════════
  Future<File> _getHistoryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}transfer_history.json');
  }

  Future<void> saveHistory(List<TransferData> history) async {
    try {
      final file = await _getHistoryFile();
      final json = history.map((t) => t.toJson()).toList();
      await file.writeAsString(jsonEncode(json));
      debugPrint('History saved: ${history.length} items');
    } catch (e) {
      debugPrint('History save error: $e');
    }
  }

  Future<List<TransferData>> loadHistory() async {
    try {
      final file = await _getHistoryFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final json = jsonDecode(content) as List;
      return json.map((e) => TransferData.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('History load error: $e');
      return [];
    }
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  }

  void dispose() {
    _transferController.close();
  }
}
