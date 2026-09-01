enum TransferType { file, text, clipboard, screenshot, image }

enum TransferStatus { pending, connecting, transferring, paused, completed, failed }

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
  final DateTime? transferStartedAt;
  final bool isPaused;

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
    this.transferStartedAt,
    this.isPaused = false,
  }) : timestamp = timestamp ?? DateTime.now();

  double get progress =>
      fileSize != null && fileSize! > 0 ? transferredBytes / fileSize! : 0;

  /// Transfer speed in bytes/second (null if not enough data)
  double? get speed {
    if (transferStartedAt == null || transferredBytes <= 0) return null;
    final elapsed = DateTime.now().difference(transferStartedAt!).inMilliseconds;
    if (elapsed < 500) return null; // need at least 500ms for meaningful speed
    return transferredBytes / (elapsed / 1000.0);
  }

  /// Estimated time remaining in seconds (null if can't calculate)
  double? get eta {
    if (speed == null || fileSize == null) return null;
    final remaining = fileSize! - transferredBytes;
    if (remaining <= 0) return 0;
    return remaining / speed!;
  }

  TransferData copyWith({
    TransferStatus? status,
    int? transferredBytes,
    String? error,
    String? filePath,
    DateTime? transferStartedAt,
    bool? isPaused,
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
      transferStartedAt: transferStartedAt ?? this.transferStartedAt,
      isPaused: isPaused ?? this.isPaused,
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
    'transferStartedAt': transferStartedAt?.toIso8601String(),
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
      transferStartedAt: json['transferStartedAt'] != null
          ? DateTime.parse(json['transferStartedAt'])
          : null,
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
