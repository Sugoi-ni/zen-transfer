import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/transfer_data.dart';
import 'encryption_service.dart';

class LocalNetworkService {
  static const int serverPort = 9876;

  ServerSocket? _serverSocket;
  String _currentDeviceName = 'ZenTransfer';
  final Map<String, DiscoveredDevice> _discoveredDevices = {};
  final StreamController<List<DiscoveredDevice>> _deviceController =
      StreamController.broadcast();
  final StreamController<IncomingTransfer> _incomingController =
      StreamController.broadcast();

  Stream<List<DiscoveredDevice>> get devicesStream => _deviceController.stream;
  Stream<IncomingTransfer> get incomingStream => _incomingController.stream;
  List<DiscoveredDevice> get devices => _discoveredDevices.values.toList();
  int get port => serverPort;

  Future<void> startServer(String deviceName) async {
    _currentDeviceName = deviceName;

    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, serverPort);
    debugPrint('TCP server on port $serverPort');
    _serverSocket!.listen(
      (socket) => _handleConnection(socket, deviceName),
      onError: (e) => debugPrint('Server error: $e'),
    );
  }

  // ═══════════════════════════════════════════
  //  CONNECTION HANDLER — Disk streaming
  // ═══════════════════════════════════════════
  void _handleConnection(Socket socket, String deviceName) async {
    try {
      socket.timeout(const Duration(seconds: 120));

      String? pendingType;
      Map<String, dynamic>? headerJson;
      String? currentFileId;

      // Disk streaming state — chunks written directly to temp file,
      // never held in memory.
      IOSink? tempSink;
      String? tempPath;
      int fileReceived = 0;
      int fileSize = 0;
      int originalSize = 0;
      String? fileName;
      String? senderName;
      bool isEncrypted = false;
      String? encKey;
      String? encIv;

      socket.listen(
        (data) {
          if (pendingType == null) {
            // HEADER PHASE
            final decoded = utf8.decode(data, allowMalformed: true);
            try {
              final json = jsonDecode(decoded) as Map<String, dynamic>;
              pendingType = json['type'] as String;
              headerJson = json;
              debugPrint('Server received header: $pendingType');

              switch (pendingType!) {
                case 'discover':
                  _handleDiscovery(socket, json, deviceName);
                  break;
                case 'file_header':
                  fileSize = json['fileSize'] as int;
                  originalSize = json['originalSize'] as int? ?? fileSize;
                  isEncrypted = json['encrypted'] as bool? ?? false;
                  encKey = json['encKey'] as String?;
                  encIv = json['encIv'] as String?;
                  currentFileId =
                      '${json['fileName']}_${DateTime.now().millisecondsSinceEpoch}';
                  fileName = json['fileName'] as String;
                  senderName = json['senderName'] as String? ?? 'Unknown';

                  // Determine final destination path (decrypted file)
                  final destinationDir = _androidDownloadDir;
                  if (!destinationDir.existsSync()) {
                    destinationDir.createSync(recursive: true);
                  }
                  final baseName = fileName!.contains('.')
                      ? fileName!.substring(0, fileName!.lastIndexOf('.'))
                      : fileName;
                  final ext = fileName!.contains('.')
                      ? '.${fileName!.split('.').last}'
                      : '';
                  var candidatePath =
                      '${destinationDir.path}${Platform.pathSeparator}$fileName';
                  var counter = 1;
                  while (File(candidatePath).existsSync()) {
                    candidatePath =
                        '${destinationDir.path}${Platform.pathSeparator}${baseName}_$counter$ext';
                    counter++;
                  }
                  final finalPath = candidatePath;

                  // Open temp file for disk streaming
                  tempPath =
                      '${Directory.systemTemp.path}${Platform.pathSeparator}zen_$currentFileId';
                  tempSink = File(tempPath!).openWrite();

                  // ACK header
                  socket.add(Uint8List.fromList(
                      utf8.encode(jsonEncode({'type': 'ack'}))));
                  socket.flush();

                  _incomingController.add(IncomingTransfer(
                    id: currentFileId,
                    type: IncomingTransferType.file,
                    fileName: fileName,
                    fileSize: originalSize,
                    senderName: senderName!,
                    status: 'receiving',
                    receivedBytes: 0,
                    filePath: null,
                    pendingFinalPath: finalPath,
                  ));
                  debugPrint(
                      'Incoming file: $fileName ($originalSize bytes, enc=$isEncrypted)');
                  break;
                case 'text':
                  _handleIncomingText(socket, json);
                  break;
                default:
                  socket.close();
              }
            } catch (_) {
              // Try merged header+data parsing (brace counting)
              _tryMergedHeader(socket, data, deviceName);
            }
          } else if (pendingType == 'file_header') {
            // FILE DATA PHASE — Write directly to disk
            tempSink!.add(data);
            fileReceived += data.length;

            _incomingController.add(IncomingTransfer(
              id: currentFileId!,
              type: IncomingTransferType.file,
              fileName: fileName!,
              fileSize: originalSize,
              senderName: senderName!,
              status: 'receiving',
              receivedBytes: fileReceived,
              filePath: null,
              pendingFinalPath: null,
            ));

            if (fileReceived >= originalSize) {
              _finalizeFile(socket, tempSink!, tempPath!, fileReceived,
                  headerJson!, currentFileId!, isEncrypted, encKey, encIv,
                  originalSize, fileName!, senderName!, null);
            }
          }
        },
        onDone: () async {
          if (pendingType == 'file_header' &&
              fileReceived > 0 &&
              fileReceived < originalSize &&
              tempSink != null &&
              tempPath != null) {
            _finalizeFile(
              socket,
              tempSink!,
              tempPath!,
                             fileReceived,
                             headerJson!,
              currentFileId!,
              isEncrypted,
              encKey,
              encIv,
              originalSize,
              fileName!,
              senderName!,
              null,
            );
          }
        },
        onError: (e) {
          debugPrint('Connection stream error: $e');
          try {
            tempSink?.close();
          } catch (_) {}
          try {
            socket.close();
          } catch (_) {}
        },
      );
    } catch (e) {
      debugPrint('Connection error: $e');
      try {
        await socket.close();
      } catch (_) {}
    }
  }

  /// Try parsing a merged header+data packet using brace counting.
  /// Try parsing a merged header+data packet using brace counting.
  Future<void> _tryMergedHeader(Socket socket, Uint8List data, String deviceName) async {
    int depth = 0;
    int jsonEnd = -1;
    for (var i = 0; i < data.length; i++) {
      if (data[i] == 0x7B) {
        depth++;
      } else if (data[i] == 0x7D) {
        depth--;
        if (depth == 0) {
          jsonEnd = i;
          break;
        }
      }
    }

    if (jsonEnd > 0) {
      final headerBytes = data.sublist(0, jsonEnd + 1);
      final headerStr = utf8.decode(headerBytes, allowMalformed: true);
      try {
        final json = jsonDecode(headerStr) as Map<String, dynamic>;
        final type = json['type'] as String;
        debugPrint('Server received (merged): $type');

        final downloadDir = _androidDownloadDir;

        switch (type) {
          case 'discover':
            _handleDiscovery(socket, json, deviceName);
            break;
          case 'file_header':
            final fileSize = json['fileSize'] as int;
            final originalSize = json['originalSize'] as int? ?? fileSize;
            final isEncrypted = json['encrypted'] as bool? ?? false;
            final encKey = json['encKey'] as String?;
            final encIv = json['encIv'] as String?;
            final currentFileId =
                '${json['fileName']}_${DateTime.now().millisecondsSinceEpoch}';
            final fileName = json['fileName'] as String;
            final senderName = json['senderName'] as String? ?? 'Unknown';

            if (!await downloadDir.exists()) {
              await downloadDir.create(recursive: true);
            }
            final baseName = fileName.contains('.')
                ? fileName.substring(0, fileName.lastIndexOf('.'))
                : fileName;
            final ext = fileName.contains('.')
                ? '.${fileName.split('.').last}'
                : '';
            var candidatePath =
                '${downloadDir.path}${Platform.pathSeparator}$fileName';
            var counter = 1;
            while (await File(candidatePath).exists()) {
              candidatePath =
                  '${downloadDir.path}${Platform.pathSeparator}${baseName}_$counter$ext';
              counter++;
            }
            final finalPath = candidatePath;

            final tempPath =
                '${Directory.systemTemp.path}${Platform.pathSeparator}zen_$currentFileId';
            final tempSink = File(tempPath!).openWrite();

            socket.add(Uint8List.fromList(
                utf8.encode(jsonEncode({'type': 'ack'}))));
            socket.flush();

            _incomingController.add(IncomingTransfer(
              id: currentFileId,
              type: IncomingTransferType.file,
              fileName: fileName,
              fileSize: originalSize,
              senderName: senderName!,
              status: 'receiving',
              receivedBytes: 0,
              filePath: null,
              pendingFinalPath: finalPath,
            ));

            // Process remaining bytes as file data
            final remaining = data.sublist(jsonEnd + 1);
            if (remaining.isNotEmpty) {
              tempSink.add(remaining);
              final received = remaining.length;
              _incomingController.add(IncomingTransfer(
                id: currentFileId,
                type: IncomingTransferType.file,
                fileName: fileName,
                fileSize: originalSize,
                senderName: senderName!,
                status: 'receiving',
                receivedBytes: received,
                filePath: null,
              ));
              if (received >= originalSize) {
                _finalizeFile(
                  socket,
                  tempSink,
                  tempPath,
                  received,
                  json,
                  currentFileId,
                  isEncrypted,
                  encKey,
                  encIv,
                  originalSize,
                  fileName,
                  senderName,
                  finalPath,
                );
              }
            }
            break;
          case 'text':
            _handleIncomingText(socket, json);
            break;
        }
      } catch (e) {
        debugPrint('Merged header parse error: $e');
      }
    }
  }

  // ═══════════════════════════════════════════
  //  FINALIZE — decrypt if needed, move to final path
  // ═══════════════════════════════════════════
  Future<void> _finalizeFile(
    Socket socket,
    IOSink tempSink,
    String tempPath,
    int totalBytes,
    Map<String, dynamic> headerJson,
    String fileId,
    bool isEncrypted,
    String? encKey,
    String? encIv,
    int originalSize,
    String fileName,
    String senderName,
    String? pendingFinalPath,
  ) async {
    if (headerJson == null) {
      try { await socket.close(); } catch (_) {}
      return;
    }

    try {
      await tempSink.flush();
    } catch (_) {}
    try {
      await tempSink.close();
    } catch (_) {}

    // Determine final path
    final destinationDir = _androidDownloadDir;
    String finalPath;
    if (pendingFinalPath != null) {
      finalPath = pendingFinalPath;
    } else {
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
      }
      final baseName = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;
      final ext = fileName.contains('.')
          ? '.${fileName.split('.').last}'
          : '';
      finalPath =
          '${destinationDir.path}${Platform.pathSeparator}$fileName';
      var counter = 1;
      while (await File(finalPath).exists()) {
        finalPath =
            '${destinationDir.path}${Platform.pathSeparator}${baseName}_$counter$ext';
        counter++;
      }
    }

    if (!isEncrypted) {
      // Non-encrypted: move temp to final path
      await _moveTempToFinal(tempPath, finalPath, fileId, fileName, originalSize, senderName);
      return;
    }

    // Encrypted: decrypt to final path, then emit received event
    try {
      final tempFile = File(tempPath);
      if (!await tempFile.exists()) {
        throw Exception('temp file not found: $tempPath');
      }

      // Read temp file (this is the encrypted data)
      final ciphertext = await tempFile.readAsBytes();

      // Decrypt using EncryptionService
      final encService = EncryptionService.fromPayload({
        'key': encKey!,
        'iv': encIv!,
      });
      final plaintext = encService.decryptData(ciphertext);

      // Write decrypted data to final path
      final finalFile = File(finalPath);
      await finalFile.writeAsBytes(plaintext);

      // Delete temp file
      try {
        await tempFile.delete();
      } catch (_) {}

      // Emit received event with filePath (no fileData blob)
      _incomingController.add(IncomingTransfer(
        id: fileId,
        type: IncomingTransferType.file,
        fileName: fileName,
        fileSize: originalSize,
        senderName: senderName!,
        status: 'received',
        receivedBytes: originalSize,
        filePath: finalPath,
      ));
      debugPrint('File received (decrypted): $fileName -> $finalPath');
    } catch (e) {
      debugPrint('Decrypt/finalize error: $e');
      // Clean up temp file on error
      try {
        await File(tempPath).delete();
      } catch (_) {}
      _incomingController.add(IncomingTransfer(
        id: fileId,
        type: IncomingTransferType.file,
        fileName: fileName,
        fileSize: originalSize,
        senderName: senderName!,
        status: 'failed',
        receivedBytes: 0,
        filePath: null,
        error: e.toString(),
      ));
    }

    try {
      await socket.close();
    } catch (_) {}
  }

  /// Move temp file to final path — handles cross-filesystem by copying.
  Future<void> _moveTempToFinal(
    String tempPath,
    String finalPath,
    String fileId,
    String fileName,
    int originalSize,
    String senderName,
  ) async {
    try {
      final tempFile = File(tempPath);
      if (!await tempFile.exists()) {
        throw Exception('temp file not found');
      }

      // Try rename first (same filesystem, fast)
      await tempFile.rename(finalPath);
      await tempFile.delete();

      _incomingController.add(IncomingTransfer(
        id: fileId,
        type: IncomingTransferType.file,
        fileName: fileName,
        fileSize: originalSize,
        senderName: senderName!,
        status: 'received',
        receivedBytes: originalSize,
        filePath: finalPath,
      ));
      debugPrint('File received (moved): $fileName -> $finalPath');
    } catch (e) {
      // Rename failed (cross-device) — copy and delete temp
      debugPrint('Rename failed, copying: $e');
      try {
        final tempFile = File(tempPath);
        final finalFile = File(finalPath);
        final sink = finalFile.openWrite();
        await for (final chunk in tempFile.openRead()) {
          sink.add(chunk);
        }
        await sink.close();
        await tempFile.delete();
      } catch (e2) {
        debugPrint('Copy fallback error: $e2');
      }

      _incomingController.add(IncomingTransfer(
        id: fileId,
        type: IncomingTransferType.file,
        fileName: fileName,
        fileSize: originalSize,
        senderName: senderName!,
        status: 'received',
        receivedBytes: originalSize,
        filePath: finalPath,
      ));
      debugPrint('File received (copied): $fileName -> $finalPath');
    }

    try {
      // Socket already closed by caller
    } catch (_) {}
  }

  // ═══════════════════════════════════════════
  //  DISCOVERY
  // ═══════════════════════════════════════════
  Future<void> _handleDiscovery(
    Socket socket,
    Map<String, dynamic> json,
    String deviceName,
  ) async {
    try {
      final response = jsonEncode({
        'type': 'found',
        'name': deviceName,
        'port': serverPort,
        'platform': defaultTargetPlatform.name,
      });
      socket.add(Uint8List.fromList(utf8.encode(response)));
      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 100));
      await socket.close();
      debugPrint('Discovery response sent: $deviceName');
    } catch (e) {
      debugPrint('Discovery response error: $e');
      try {
        await socket.close();
      } catch (_) {}
    }
  }

  // ═══════════════════════════════════════════
  //  INCOMING TEXT
  // ═══════════════════════════════════════════
  Future<void> _handleIncomingText(
    Socket socket,
    Map<String, dynamic> json,
  ) async {
    final content = json['content'] as String;
    final senderName = json['senderName'] as String? ?? 'Unknown';
    debugPrint('Incoming text from $senderName');

    socket.add(Uint8List.fromList(
        utf8.encode(jsonEncode({'type': 'ack'}))));
    await socket.flush();
    await socket.close();

    _incomingController.add(IncomingTransfer(
      type: IncomingTransferType.text,
      textContent: content,
      senderName: senderName!,
      status: 'completed',
    ));
  }

  // ═══════════════════════════════════════════
  //  SCAN
  // ═══════════════════════════════════════════
  Future<List<DiscoveredDevice>> scanForDevices() async {
    _discoveredDevices.clear();
    _deviceController.add([]);

    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      if (wifiIP == null) {
        debugPrint('No WiFi IP found');
        return [];
      }

      final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
      debugPrint('Scanning subnet: $subnet.* from $wifiIP');

      final futures = <Future>[];
      for (var i = 1; i < 255; i++) {
        final address = '$subnet.$i';
        if (address == wifiIP) continue;

        futures.add(_probeDevice(address).then((device) {
          if (device != null) {
            _discoveredDevices[device.id] = device;
            _deviceController.add(devices);
          }
        }));
      }

      await Future.wait(futures).catchError((_) => <void>[]);
      debugPrint('Scan complete. Found ${devices.length} devices');
      _deviceController.add(devices);
      return devices;
    } catch (e) {
      debugPrint('Scan error: $e');
      return [];
    }
  }

  Future<DiscoveredDevice?> _probeDevice(String address) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        address,
        serverPort,
        timeout: const Duration(milliseconds: 1000),
      );

      final message = jsonEncode({
        'type': 'discover',
        'name': _currentDeviceName,
      });
      socket.add(Uint8List.fromList(utf8.encode(message)));
      await socket.flush();

      final response = await socket.first.timeout(const Duration(seconds: 2));

      final chars = <int>[];
      for (final byte in response) {
        chars.add(byte);
      }
      final decoded = String.fromCharCodes(chars);
      debugPrint('Probe $address: $decoded');

      final json = jsonDecode(decoded);
      if (json is Map<String, dynamic> && json['type'] == 'found') {
        return DiscoveredDevice(
          id: '$address:$serverPort',
          name: json['name'] as String,
          ip: address,
          port: serverPort,
          platform: json['platform'] as String? ?? 'unknown',
        );
      }
    } catch (e) {
      // Connection refused or timeout
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
    return null;
  }

  Future<Socket> connectToDevice(DiscoveredDevice device) async {
    return await Socket.connect(
      device.ip,
      device.port,
      timeout: const Duration(seconds: 5),
    );
  }

  void stop() {
    _serverSocket?.close();
    _serverSocket = null;
  }

  /// Android download directory
  Directory get _androidDownloadDir =>
      Directory('/storage/emulated/0/Download/ZenTransfer');
}

// ═══════════════════════════════════════════
//  Incoming transfer event
// ═══════════════════════════════════════════
enum IncomingTransferType { file, text }

class IncomingTransfer {
  final String id;
  final IncomingTransferType type;
  final String? fileName;
  final int? fileSize;
  final String senderName;
  final String status; // receiving, received, completed, failed
  final int receivedBytes;
  final String? filePath; // final disk path (no in-memory blob)
  final String? textContent;
  final String? error;
  final String? pendingFinalPath;

  IncomingTransfer({
    String? id,
    required this.type,
    this.fileName,
    this.fileSize,
    required this.senderName,
    required this.status,
    this.receivedBytes = 0,
    this.filePath,
    this.textContent,
    this.error,
    this.pendingFinalPath,
  }) : id = id ??
            '${fileName ?? 'text'}_${DateTime.now().millisecondsSinceEpoch}';
}
