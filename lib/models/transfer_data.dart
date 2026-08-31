enum TransferType { file, text, clipboard, screenshot, image }

enum TransferStatus { pending, connecting, transferring, completed, failed }

enum ConnectionMode { local, internet }

class TransferData {
  final String id;
  final String senderName;
  final String receiverName;
  final TransferType type;
  final TransferStatus status;
  final String? filePath;
  final String? fileName;
  final String? textContent;
  final int? fileSize;
  final int transferredBytes;
  final DateTime timestamp;
  final ConnectionMode mode;
  final bool encrypted;
  final String? error;

  TransferData({
    required this.id,
    required this.senderName,
    required this.receiverName,
    required this.type,
    this.status = TransferStatus.pending,
    this.filePath,
    this.fileName,
    this.textContent,
    this.fileSize,
    this.transferredBytes = 0,
    DateTime? timestamp,
    this.mode = ConnectionMode.local,
    this.encrypted = true,
    this.error,
  }) : timestamp = timestamp ?? DateTime.now();

  double get progress =>
      fileSize != null && fileSize! > 0 ? transferredBytes / fileSize! : 0;

  TransferData copyWith({
    TransferStatus? status,
    int? transferredBytes,
    String? error,
    String? filePath,
  }) {
    return TransferData(
      id: id,
      senderName: senderName,
      receiverName: receiverName,
      type: type,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      fileName: fileName,
      textContent: textContent,
      fileSize: fileSize,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      timestamp: timestamp,
      mode: mode,
      encrypted: encrypted,
      error: error,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderName': senderName,
    'receiverName': receiverName,
    'type': type.name,
    'status': status.name,
    'filePath': filePath,
    'fileName': fileName,
    'textContent': textContent,
    'fileSize': fileSize,
    'transferredBytes': transferredBytes,
    'timestamp': timestamp.toIso8601String(),
    'mode': mode.name,
    'encrypted': encrypted,
  };

  factory TransferData.fromJson(Map<String, dynamic> json) {
    return TransferData(
      id: json['id'],
      senderName: json['senderName'],
      receiverName: json['receiverName'],
      type: TransferType.values.byName(json['type']),
      status: TransferStatus.values.byName(json['status']),
      filePath: json['filePath'],
      fileName: json['fileName'],
      textContent: json['textContent'],
      fileSize: json['fileSize'],
      transferredBytes: json['transferredBytes'] ?? 0,
      timestamp: DateTime.parse(json['timestamp']),
      mode: ConnectionMode.values.byName(json['mode']),
      encrypted: json['encrypted'] ?? true,
    );
  }
}

class DiscoveredDevice {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String platform;
  final DateTime lastSeen;
  final bool paired;

  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.platform,
    DateTime? lastSeen,
    this.paired = false,
  }) : lastSeen = lastSeen ?? DateTime.now();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
