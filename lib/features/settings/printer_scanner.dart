import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PrinterScanner {
  final NetworkInfo _info = NetworkInfo();

  Future<List<String>> scanForPrinters({
    Duration timeout = const Duration(milliseconds: 200),
    Function(double progress)? onProgress,
  }) async {
    // 1. Check permissions (Android needs location for WiFi info)
    if (Platform.isAndroid) {
      if (await Permission.location.request().isDenied) {
        throw Exception('Location permission required to scan WiFi');
      }
    }

    // 2. Get IP
    final ip = await _info.getWifiIP();
    if (ip == null || ip.isEmpty) {
      // Fallback: try to find a non-loopback interface
      final interfaces = await NetworkInterface.list();
      for (final i in interfaces) {
        for (final addr in i.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return _scanSubnet(addr.address, timeout, onProgress);
          }
        }
      }
      throw Exception('No WiFi or network connection found');
    }

    return _scanSubnet(ip, timeout, onProgress);
  }

  Future<List<String>> _scanSubnet(
      String myIp,
      Duration timeout,
      Function(double)? onProgress,
      ) async {
    final parts = myIp.split('.');
    if (parts.length != 4) return [];

    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
    final found = <String>[];
    final futures = <Future>[];

    // Scan 1..254
    for (var i = 1; i < 255; i++) {
      final target = '$prefix.$i';
      futures.add(_checkPort(target, 9100, timeout).then((isOpen) {
        if (isOpen) found.add(target);
        if (onProgress != null) {
          onProgress(i / 255.0);
        }
      }));
    }

    await Future.wait(futures);
    if (onProgress != null) onProgress(1.0);
    return found;
  }

  Future<bool> _checkPort(String ip, int port, Duration timeout) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
