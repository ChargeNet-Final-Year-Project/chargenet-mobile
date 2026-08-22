import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The rounded cut-out, corner brackets and helper pill drawn on top of the
/// camera preview in the QR scan mode.
///
/// It is a pure overlay: the caller stacks it over `MobileScanner` (or over any
/// other dark surface), so it stays testable without a camera.
class QrViewfinderWidget extends StatelessWidget {
  const QrViewfinderWidget({
    super.key,
    this.torchOn = false,
    this.onToggleTorch,
    this.message,
  });

  /// Whether the flashlight is currently on.
  final bool torchOn;

  /// Omitted on devices without a torch / when the scanner is unavailable.
  final VoidCallback? onToggleTorch;

  /// One-line instruction under the frame.
  final String? message;

  /// Corner bracket length.
  static const double bracketLength = 34;

  static const double bracketWidth = 4;

  static const double frameRadius = 28;

  /// Side of the square cut-out for a viewport of [size]: 70 % of the shorter
  /// edge, never smaller than 180 px nor larger than 300 px.
  static double frameSize(Size size) {
    final shortest = math.min(size.width, size.height);
    return (shortest * 0.7).clamp(180.0, 300.0);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, frameConstraints) {
                  final area = frameConstraints.biggest;
                  final frame = math.min(
                    frameSize(area),
                    math.max(0.0, math.min(area.width, area.height) - 24),
                  );
                  return IgnorePointer(
                    child: SizedBox.expand(
                      child: CustomPaint(
                        painter: _ViewfinderPainter(
                          frame: frame,
                          radius: frameRadius,
                          accent: accent,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: size.height * .55),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    if (message != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            message!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    if (onToggleTorch != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _TorchButton(
                          on: torchOn,
                          accent: accent,
                          onPressed: onToggleTorch!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Round flashlight toggle that floats under the viewfinder.
class _TorchButton extends StatelessWidget {
  const _TorchButton({
    required this.on,
    required this.accent,
    required this.onPressed,
  });

  final bool on;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: on ? 'Turn off the flashlight' : 'Turn on the flashlight',
      child: Material(
        color: on ? accent : Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(
              on ? Icons.flashlight_on : Icons.flashlight_off,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dims everything except the scan frame and strokes the corner brackets.
class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter({
    required this.frame,
    required this.radius,
    required this.accent,
  });

  final double frame;
  final double radius;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: frame,
      height: frame,
    );

    final scrim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, Radius.circular(radius)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      scrim,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final brackets = Paint()
      ..color = accent
      ..strokeWidth = QrViewfinderWidget.bracketWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const len = QrViewfinderWidget.bracketLength;
    final path = Path()
      // top-left
      ..moveTo(hole.left, hole.top + len)
      ..lineTo(hole.left, hole.top)
      ..lineTo(hole.left + len, hole.top)
      // top-right
      ..moveTo(hole.right - len, hole.top)
      ..lineTo(hole.right, hole.top)
      ..lineTo(hole.right, hole.top + len)
      // bottom-right
      ..moveTo(hole.right, hole.bottom - len)
      ..lineTo(hole.right, hole.bottom)
      ..lineTo(hole.right - len, hole.bottom)
      // bottom-left
      ..moveTo(hole.left + len, hole.bottom)
      ..lineTo(hole.left, hole.bottom)
      ..lineTo(hole.left, hole.bottom - len);

    canvas.drawPath(path, brackets);
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) =>
      old.frame != frame || old.radius != radius || old.accent != accent;
}
