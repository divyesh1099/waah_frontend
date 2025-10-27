// lib/app/jwt.dart
import 'dart:convert';

Map<String, dynamic> decodeJwtClaims(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return {};
    String norm(String s) => s.padRight(s.length + (4 - s.length % 4) % 4, '=');
    final payload = utf8.decode(base64Url.decode(norm(parts[1])));
    final obj = json.decode(payload);
    return (obj is Map<String, dynamic>) ? obj : {};
  } catch (_) {
    return {};
  }
}
