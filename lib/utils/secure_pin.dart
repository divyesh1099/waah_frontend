// lib/utils/secure_pin.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Derive a salted hash so we never store the raw PIN.
/// Keep it device/tenant/mobile bound so it’s useless elsewhere.
String hashPin({
  required String mobile,
  required String pin,
  required String salt, // random UUID we store once
}) {
  final bytes = utf8.encode('$mobile::$pin::$salt');
  return sha256.convert(bytes).toString();
}

bool verifyPin({
  required String mobile,
  required String pin,
  required String salt,
  required String storedHash,
}) {
  return hashPin(mobile: mobile, pin: pin, salt: salt) == storedHash;
}
