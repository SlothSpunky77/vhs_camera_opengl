import 'package:flutter/material.dart';

import '../../utils/formatting.dart';
import '../vhs_theme.dart';

/// The on-screen display a camcorder burns into the tape itself.
///
/// This widget sits *inside* the recorded [RepaintBoundary], so whatever it
/// shows ends up in the saved photo or video.
class TapeOsd extends StatefulWidget {
  const TapeOsd({
    required this.showStamp,
    required this.recording,
    required this.elapsed,
    super.key,
  });

  final bool showStamp;
  final bool recording;
  final Duration elapsed;

  @override
  State<TapeOsd> createState() => _TapeOsdState();
}

class _TapeOsdState extends State<TapeOsd> {
  DateTime _now = DateTime.now();
  late final Stream<void> _tick;

  @override
  void initState() {
    super.initState();
    _tick = Stream<void>.periodic(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: _tick,
      builder: (BuildContext context, _) {
        _now = DateTime.now();
        final bool blink = _now.second.isEven;
        return IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Stack(
              children: <Widget>[
                if (widget.recording)
                  Align(
                    alignment: Alignment.topLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Opacity(
                          opacity: blink ? 1 : 0.25,
                          child: const Icon(
                            Icons.circle,
                            size: 11,
                            color: VhsTheme.record,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _osdText('REC ${formatTimecode(widget.elapsed)}'),
                      ],
                    ),
                  ),
                if (widget.showStamp)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _osdText('SP'),
                        const SizedBox(height: 2),
                        _osdText(formatOsdStamp(_now)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _osdText(String value) {
    return Text(
      value,
      style: VhsTheme.mono(size: 13, color: VhsTheme.osd).copyWith(
        shadows: const <Shadow>[
          Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(1, 1)),
        ],
      ),
    );
  }
}
