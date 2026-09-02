// ignore_for_file: avoid_print
// Standalone checksum roundtrip test for ZenTransfer.
// Generates a random 1 MB buffer, computes its SHA-256 hex digest,
// serializes/deserializes through JSON, recomputes, and verifies equality.
//
// Usage: dart run tool/checksum_test.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

void main() {
  final random = Random.secure();

  // 1. Generate random 1 MB buffer
  final size = 1024 * 1024; // 1 MB
  final buffer = List<int>.generate(size, (_) => random.nextInt(256));

  // 2. Compute sha256 hex digest
  final digest = sha256.convert(buffer);
  final hexString = digest.toString();

  // 3. Roundtrip through JSON (simulates header serialization)
  final jsonEncoded = jsonEncode({'checksum': hexString});
  final jsonDecoded = jsonDecode(jsonEncoded) as Map<String, dynamic>;
  final roundtrippedHex = jsonDecoded['checksum'] as String;

  // 4. Recompute sha256 on original buffer
  final recompute = sha256.convert(buffer);
  final recomputeHex = recompute.toString();

  // 5. Verify
  final match = (hexString == roundtrippedHex) && (hexString == recomputeHex);

  print('Buffer size:      $size bytes');
  print('SHA-256 hex:      $hexString');
  print('After JSON roundtrip: $roundtrippedHex');
  print('Recomputed:       $recomputeHex');
  print('');
  print('Roundtrip match:  ${match ? "PASS" : "FAIL"}');

  if (!match) {
    print('ERROR: Checksum roundtrip verification failed!');
    exit(1);
  }
}
