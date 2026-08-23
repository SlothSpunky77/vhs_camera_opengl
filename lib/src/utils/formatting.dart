/// Formats a duration as a camcorder timecode, e.g. `00:01:23`.
String formatTimecode(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final int hours = d.inHours;
  final int minutes = d.inMinutes.remainder(60);
  final int seconds = d.inSeconds.remainder(60);
  if (hours > 0) return '${two(hours)}:${two(minutes)}:${two(seconds)}';
  return '${two(minutes)}:${two(seconds)}';
}

/// Formats a timestamp the way a 1990s camcorder burnt it into the tape.
String formatOsdStamp(DateTime now) {
  String two(int v) => v.toString().padLeft(2, '0');
  final int hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
  final String meridiem = now.hour < 12 ? 'AM' : 'PM';
  return '${two(now.month)}.${two(now.day)}.${now.year} '
      '${two(hour12)}:${two(now.minute)} $meridiem';
}

/// Formats a zoom factor as `1.0x`.
String formatZoom(double zoom) => '${zoom.toStringAsFixed(1)}x';

/// Formats an exposure offset as `+0.0` / `-1.3`.
String formatExposure(double ev) =>
    '${ev >= 0 ? '+' : '-'}${ev.abs().toStringAsFixed(1)}';
