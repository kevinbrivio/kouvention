import 'dart:io';

class SecurityService {
  static const _androidRootPaths = [
    '/sbin/su',
    '/system/bin/su',
    '/system/xbin/su',
    '/data/local/xbin/su',
    '/data/local/bin/su',
    '/system/sd/xbin/su',
    '/system/bin/failsafe/su',
    '/data/local/su',
    '/su/bin/su',
    '/system/app/Superuser.apk',
    '/data/data/com.topjohnwu.magisk',
    '/data/data/com.noshufou.android.su',
  ];
  static const _iosJailbreakPaths = [
    '/Applications/Cydia.app',
    '/Applications/Sileo.app',
    '/Library/MobileSubstrate/MobileSubstrate.dylib',
    '/bin/bash',
    '/usr/sbin/sshd',
    '/etc/apt',
    '/private/var/lib/apt/',
  ];

  static Future<bool> isDeviceRooted() async {
    try {
      if (Platform.isAndroid) {
        return await _checkPaths(_androidRootPaths);
      } else if (Platform.isIOS) {
        return await _checkPaths(_iosJailbreakPaths);
      }
    } catch (_) {}

    return false;
  }

  static Future<bool> _checkPaths(List<String> paths) async {
    for (final path in paths) {
      if (await File(path).exists() || await Directory(path).exists()) {
        return true;
      }
    }
    
    return false;
  }
}
