import 'package:flutter_test/flutter_test.dart';
import 'package:vhs_camera/src/utils/formatting.dart';

void main() {
  test('timecode uses mm:ss below an hour and hh:mm:ss above', () {
    expect(formatTimecode(Duration.zero), '00:00');
    expect(formatTimecode(const Duration(seconds: 65)), '01:05');
    expect(
      formatTimecode(const Duration(hours: 2, minutes: 3, seconds: 4)),
      '02:03:04',
    );
  });

  test('OSD stamp uses the 12 hour camcorder format', () {
    expect(
      formatOsdStamp(DateTime(1994, 8, 7, 15, 4)),
      '08.07.1994 03:04 PM',
    );
    expect(
      formatOsdStamp(DateTime(2026, 1, 2, 0, 9)),
      '01.02.2026 12:09 AM',
    );
  });

  test('zoom and exposure readouts are fixed width', () {
    expect(formatZoom(1), '1.0x');
    expect(formatZoom(10.55), '10.6x');
    expect(formatExposure(0), '+0.0');
    expect(formatExposure(-1.25), '-1.3');
  });
}
