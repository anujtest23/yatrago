import 'dart:io';

import 'package:flutter/foundation.dart';

/// Best-effort runtime environment checks (root / emulator / debugger /
/// instrumentation). Pure Dart — no native plugin required.
///
/// These are SIGNALS, not enforcement: results are reported to the backend
/// (X-Device-Integrity header) where the fraud engine weighs them against
/// other behaviour. A determined attacker can strip the header; that is
/// fine — this catches the long tail of lazy fraud (rooted farm phones,
/// emulator fleets), while server-side attestation (Play Integrity) remains
/// the eventual strong check.
class DeviceIntegrity {
  DeviceIntegrity._();

  static List<String>? _cached;

  /// Flag names understood by the backend: rooted, emulator, debug, frida.
  static Future<List<String>> check() async {
    if (_cached != null) return _cached!;
    final flags = <String>[];

    if (kDebugMode) flags.add('debug');

    if (Platform.isAndroid) {
      if (_anyExists(_suPaths)) flags.add('rooted');
      if (_anyExists(_emulatorArtifacts)) flags.add('emulator');
      if (await _fridaPortOpen()) flags.add('frida');
    }

    _cached = flags;
    return flags;
  }

  static const _suPaths = [
    '/system/bin/su',
    '/system/xbin/su',
    '/sbin/su',
    '/su/bin/su',
    '/data/local/bin/su',
    '/data/local/xbin/su',
    '/system/app/Superuser.apk',
    '/system/app/SuperSU.apk',
    '/data/adb/magisk',
    '/system/xbin/busybox',
  ];

  static const _emulatorArtifacts = [
    '/dev/socket/qemud',
    '/dev/qemu_pipe',
    '/system/lib/libc_malloc_debug_qemu.so',
    '/system/bin/qemu-props',
  ];

  static bool _anyExists(List<String> paths) {
    for (final p in paths) {
      try {
        if (File(p).existsSync() || Directory(p).existsSync()) return true;
      } catch (_) {
        // Permission errors mean "can't tell", not "compromised".
      }
    }
    return false;
  }

  /// Frida's default server listens on 27042 — a cheap, high-precision tell.
  static Future<bool> _fridaPortOpen() async {
    try {
      final socket = await Socket.connect(
        '127.0.0.1',
        27042,
        timeout: const Duration(milliseconds: 300),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
