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

    // Server started
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

      // Disk streaming state
      IOSink? tempSink;
      String? tempPath;
      var fileReceived = 0;
      var fileSize = 0;
      var originalSize = 0;
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

                  // Open temp file for disk streaming
                  tempPath = '${Directory.systemTemp.path}${Platform.pathSeparator}zen_$currentFileId';
                  tempSink = File(tempPath!).openWrite();

                  socket.add(Uint8List.fromList(
                      utf8.encode(jsonEncode({'type': 'ack'}))));
                  socket.flush();
                  _incomingController.add(IncomingTransfer(
                    id: currentFileId,
                    type: IncomingTransferType.file,
                    fileName: json['fileName'] as String,
                    fileSize: originalSize,
                    senderName: json['senderName'] as String? ?? 'Unknown',
                    status: 'receiving',
                  ));
                  debugPrint('Incoming file: ${json['fileName']} ($fileSize bytes, enc=$isEncrypted)');
                  break;
                case 'text':
                  _handleIncomingText(socket, json);
                  break;
                default:
                  socket.close();
              }
            } catch (_) {
              // Try merged header+data parsing (brace counting)
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
                  pendingType = type;
                  headerJson = json;
                  debugPrint('Server received (merged): $type');

                  switch (type) {
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

                      tempPath = '${Directory.systemTemp.path}${Platform.pathSeparator}zen_$currentFileId';
                      tempSink = File(tempPath!).openWrite();

                      socket.add(Uint8List.fromList(
                          utf8.encode(jsonEncode({'type': 'ack'}))));
                      socket.flush();
                      _incomingController.add(IncomingTransfer(
                        id: currentFileId,
                        type: IncomingTransferType.file,
                        fileName: json['fileName'] as String,
                        fileSize: originalSize,
                        senderName: json['senderName'] as String? ?? 'Unknown',
                        status: 'receiving',
                      ));

                      // Process remaining bytes as file data
                      final remaining = data.sublist(jsonEnd + 1);
                      if (remaining.isNotEmpty) {
                        tempSink!.add(remaining);
                        fileReceived += remaining.length;
                        debugPrint('Merged: ${remaining.length} bytes file data');
                        _emitReceivingProgress(currentFileId!, json, fileReceived, fileSize);
                        if (fileReceived >= fileSize) {
                          _finalizeFromDisk(socket, tempSink, tempPath!,
                              fileReceived, headerJson,
                              fileId: currentFileId,
                              isEncrypted: isEncrypted,
                              encKey: encKey, encIv: encIv,
                              originalSize: originalSize);
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
          } else if (pendingType == 'file_header') {
            // FILE DATA PHASE — Write directly to disk
            tempSink!.add(data);
            fileReceived += data.length;

            _emitReceivingProgress(currentFileId!, headerJson!, fileReceived, fileSize);

            if (fileReceived >= fileSize) {
              _finalizeFromDisk(socket, tempSink!, tempPath!,
                  fileReceived, headerJson,
                  fileId: currentFileId,
                  isEncrypted: isEncrypted,
                  encKey: encKey, encIv: encIv,
                  originalSize: originalSize);
            }
          }
        },
        onDone: () async {
          if (pendingType == 'file_header' && fileReceived > 0 && fileReceived < fileSize) {
            _finalizeFromDisk(socket, tempSink, tempPath!,
                fileReceived, headerJson,
                fileId: currentFileId,
                isEncrypted: isEncrypted,
                encKey: encKey, encIv: encIv,
                originalSize: originalSize);
          }
        },
        onError: (e) {
          debugPrint('Connection stream error: $e');
          tempSink?.close();
          try { socket.close(); } catch (_) {}
        },
      );
    } catch (e) {
      debugPrint('Connection error: $e');
      try { await socket.close(); } catch (_) {}
    }
  }

  void _emitReceivingProgress(String fileId, Map<String, dynamic> json, int received, int total) {
    _incomingController.add(IncomingTransfer(
      id: fileId,
      type: IncomingTransferType.file,
      fileName: json['fileName'] as String,
      fileSize: json['originalSize'] as int? ?? total,
      senderName: json['senderName'] as String? ?? 'Unknown',
      status: 'receiving',
      receivedBytes: received,
    ));
  }

  // ═══════════════════════════════════════════
  //  FINALIZE — Read from temp file, decrypt, save
  // ═══════════════════════════════════════════
  void _finalizeFromDisk(
    Socket socket,
    IOSink? tempSink,
    String tempPath,
    int totalBytes,
    Map<String, dynamic>? headerJson, {
    String? fileId,
    bool isEncrypted = false,
    String? encKey,
    String? encIv,
    int? originalSize,
  }) async {
    if (headerJson == null) return;

    try {
      await tempSink?.flush();
      await tempSink?.close();
    } catch (_) {}

    try {
      var fileData = await File(tempPath).readAsBytes();
      debugPrint('Temp file read: ${fileData.length} bytes');

      // Decrypt if encrypted
      if (isEncrypted && encKey != null && encIv != null) {
        try {
          final encService = EncryptionService.fromPayload({
            'key': encKey,
            'iv': encIv,
          });
          fileData = encService.decryptData(fileData);
          debugPrint('Decrypted: $totalBytes -> ${fileData.length} bytes');
        } catch (e) {
          debugPrint('Decryption error: $e');
        }
      }

      // Verify checksum (skip if sender didn't include one — backward compat)
      final expectedChecksum = headerJson['checksum'] as String?;
      if (expectedChecksum != null) {
        final actualChecksum = sha256.convert(fileData).toString();
        if (actualChecksum != expectedChecksum) {
          debugPrint(
            'Checksum mismatch! Expected: $expectedChecksum, got: $actualChecksum',
          );
          _incomingController.add(IncomingTransfer(
            id: fileId,
            type: IncomingTransferType.file,
            fileName: headerJson['fileName'] as String,
            fileSize: originalSize ?? headerJson['fileSize'] as int,
            senderName: headerJson['senderName'] as String? ?? 'Unknown',
            status: 'checksum_mismatch',
            receivedBytes: fileData.length,
          ));
          // Clean up temp file on mismatch
          try { await File(tempPath).delete(); } catch (_) {}
          try { await socket.close(); } catch (_) {}
          return;
        }
        debugPrint('Checksum verified: $actualChecksum');
      }

      _incomingController.add(IncomingTransfer(
        id: fileId,
        type: IncomingTransferType.file,
        fileName: headerJson['fileName'] as String,
        fileSize: originalSize ?? headerJson['fileSize'] as int,
        senderName: headerJson['senderName'] as String? ?? 'Unknown',
        status: 'received',
        receivedBytes: fileData.length,
        fileData: fileData,
      ));

      debugPrint('File received: ${headerJson['fileName']} (${fileData.length} bytes)');

      // Clean up temp file
      try { await File(tempPath).delete(); } catch (_) {}
    } catch (e) {
      debugPrint('Finalize error: $e');
    }

    try { await socket.close(); } catch (_) {}
  }

  Future<void> _handleDiscovery(
      Socket socket, Map<String, dynamic> json, String deviceName) async {
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
      try { await socket.close(); } catch (_) {}
    }
  }

  Future<void> _handleIncomingText(
      Socket socket, Map<String, dynamic> json) async {
    final content = json['content'] as String;
    final senderName = json['senderName'] as String? ?? 'Unknown';
    debugPrint('Incoming text from $senderName');

    socket.add(Uint8List.fromList(utf8.encode(jsonEncode({'type': 'ack'}))));
    await socket.flush();
    await socket.close();

    _incomingController.add(IncomingTransfer(
      type: IncomingTransferType.text,
      textContent: content,
      senderName: senderName,
      status: 'completed',
    ));
  }

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
      try { await socket?.close(); } catch (_) {}
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
}

enum IncomingTransferType { file, text }

class IncomingTransfer {
  final String id;
  final IncomingTransferType type;
  final String? fileName;
  final int? fileSize;
  final String senderName;
  final String status; // receiving, received, completed, failed
  final int receivedBytes;
  final Uint8List? fileData;
  final String? textContent;

  IncomingTransfer({
    String? id,
    required this.type,
    this.fileName,
    this.fileSize,
    required this.senderName,
    required this.status,
    this.receivedBytes = 0,
    this.fileData,
    this.textContent,
  }) : id = id ?? '${fileName ?? "text"}_${DateTime.now().millisecondsSinceEpoch}';
}
