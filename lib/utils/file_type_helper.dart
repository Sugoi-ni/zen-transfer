import 'package:flutter/material.dart';

class FileTypeHelper {
  static const _imageExtensions = [
    'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp', 'svg', 'ico', 'tiff',
  ];
  static const _videoExtensions = [
    'mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v',
  ];
  static const _audioExtensions = [
    'mp3', 'wav', 'ogg', 'flac', 'aac', 'wma', 'm4a',
  ];
  static const _docExtensions = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'csv',
  ];
  static const _archiveExtensions = [
    'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz',
  ];
  static const _codeExtensions = [
    'dart', 'js', 'ts', 'py', 'java', 'cpp', 'c', 'h', 'html', 'css',
    'json', 'yaml', 'xml', 'sql', 'sh', 'bat', 'ps1', 'rb', 'go', 'rs',
  ];
  static const _apkExtensions = ['apk', 'aab'];
  static const _exeExtensions = ['exe', 'msi', 'app', 'dmg', 'deb', 'rpm'];

  /// Get the icon for a file based on its extension
  static IconData getIcon(String fileName) {
    final ext = _getExtension(fileName).toLowerCase();

    if (_imageExtensions.contains(ext)) return Icons.image_rounded;
    if (_videoExtensions.contains(ext)) return Icons.videocam_rounded;
    if (_audioExtensions.contains(ext)) return Icons.audiotrack_rounded;
    if (_docExtensions.contains(ext)) return Icons.description_rounded;
    if (_archiveExtensions.contains(ext)) return Icons.folder_zip_rounded;
    if (_codeExtensions.contains(ext)) return Icons.code_rounded;
    if (_apkExtensions.contains(ext)) return Icons.android_rounded;
    if (_exeExtensions.contains(ext)) return Icons.memory_rounded;
    if (ext == 'json') return Icons.data_object_rounded;

    return Icons.insert_drive_file_rounded;
  }

  /// Get the color for a file type
  static Color getColor(String fileName) {
    final ext = _getExtension(fileName).toLowerCase();

    if (_imageExtensions.contains(ext)) return const Color(0xFF4CAF50);
    if (_videoExtensions.contains(ext)) return const Color(0xFFE91E63);
    if (_audioExtensions.contains(ext)) return const Color(0xFFFF9800);
    if (_docExtensions.contains(ext)) return const Color(0xFF2196F3);
    if (_archiveExtensions.contains(ext)) return const Color(0xFF9C27B0);
    if (_codeExtensions.contains(ext)) return const Color(0xFF00BCD4);
    if (_apkExtensions.contains(ext)) return const Color(0xFF8BC34A);
    if (_exeExtensions.contains(ext)) return const Color(0xFF607D8B);

    return const Color(0xFF9E9E9E);
  }

  /// Get a preview-friendly description of the file type
  static String getTypeLabel(String fileName) {
    final ext = _getExtension(fileName).toLowerCase();

    if (_imageExtensions.contains(ext)) return 'Image';
    if (_videoExtensions.contains(ext)) return 'Video';
    if (_audioExtensions.contains(ext)) return 'Audio';
    if (_docExtensions.contains(ext)) return 'Document';
    if (_archiveExtensions.contains(ext)) return 'Archive';
    if (_codeExtensions.contains(ext)) return 'Code';
    if (_apkExtensions.contains(ext)) return 'App';
    if (_exeExtensions.contains(ext)) return 'Executable';

    return 'File';
  }

  /// Check if the file is a media type (image/video/audio)
  static bool isMedia(String fileName) {
    final ext = _getExtension(fileName).toLowerCase();
    return _imageExtensions.contains(ext) ||
        _videoExtensions.contains(ext) ||
        _audioExtensions.contains(ext);
  }

  /// Check if the file is an image
  static bool isImage(String fileName) {
    final ext = _getExtension(fileName).toLowerCase();
    return _imageExtensions.contains(ext);
  }

  static String _getExtension(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1 || lastDot == fileName.length - 1) return '';
    return fileName.substring(lastDot + 1);
  }
}
