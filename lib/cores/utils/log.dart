import 'package:flutter/foundation.dart';

String _caller() {
  final frames = StackTrace.current.toString().split('\n');
  // frame 0 = _caller, frame 1 = _log, frame 2 = dLog/iLog/wLog/eLog, frame 3 = actual caller
  if (frames.length < 4) return '';
  final match = RegExp(r'#3\s+\S+\s+\((.+)\)').firstMatch(frames[3]);
  if (match == null) return '';
  final uri = match.group(1)!;
  // Strip to just filename:line from the full URI
  final file = RegExp(r'[^/]+\.dart:\d+').firstMatch(uri);
  return file?.group(0) ?? uri;
}

void _log(String label, String message) {
  if (!kDebugMode) return;
  final source = _caller();
  final header = '========================  $label  ========================';
  final footer = '=' * header.length;
  final prefix = source.isEmpty ? '' : '[$source] ';
  debugPrint('$header\n$prefix$message\n$footer');
}

void dLog(String message) => _log('DEBUG', message);
void iLog(String message) => _log('INFO', message);
void wLog(String message) => _log('WARNING', message);
void eLog(String message) => _log('ERROR', message);
